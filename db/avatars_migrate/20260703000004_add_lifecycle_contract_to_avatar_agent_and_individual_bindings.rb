# frozen_string_literal: true

class AddLifecycleContractToAvatarAgentAndIndividualBindings < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  class AvatarAgentBindingBackfill < ActiveRecord::Base
    self.table_name = "avatar_agent_bindings"
  end

  class AvatarIndividualBindingBackfill < ActiveRecord::Base
    self.table_name = "avatar_individual_bindings"
  end

  def up
    add_lifecycle_columns(:avatar_agent_bindings)
    add_lifecycle_columns(:avatar_individual_bindings)

    backfill_lifecycle_columns(AvatarAgentBindingBackfill)
    backfill_lifecycle_columns(AvatarIndividualBindingBackfill)
    assert_no_active_uniqueness_violations(AvatarAgentBindingBackfill, :agent_id)
    assert_no_active_uniqueness_violations(AvatarIndividualBindingBackfill, :individual_id)

    add_not_null_constraint(:avatar_agent_bindings, :public_id)
    add_not_null_constraint(:avatar_agent_bindings, :assigned_at)
    add_not_null_constraint(:avatar_individual_bindings, :public_id)
    add_not_null_constraint(:avatar_individual_bindings, :assigned_at)

    replace_bare_unique_indexes(
      :avatar_agent_bindings,
      :agent_id,
      active_pair: "idx_avatar_agent_bindings_active_pair",
      active_avatar: "idx_avatar_agent_bindings_active_avatar",
      active_subject: "idx_avatar_agent_bindings_active_agent",
    )
    replace_bare_unique_indexes(
      :avatar_individual_bindings,
      :individual_id,
      active_pair: "idx_avatar_individual_bindings_active_pair",
      active_avatar: "idx_avatar_individual_bindings_active_avatar",
      active_subject: "idx_avatar_individual_bindings_active_individual",
    )

    add_index(:avatar_agent_bindings, :public_id, unique: true, if_not_exists: true, algorithm: :concurrently)
    add_index(:avatar_individual_bindings, :public_id, unique: true, if_not_exists: true, algorithm: :concurrently)

    add_revoked_ordering_constraint(
      :avatar_agent_bindings,
      "chk_avatar_agent_bindings_revoked_after_assigned",
    )
    add_revoked_ordering_constraint(
      :avatar_individual_bindings,
      "chk_avatar_individual_bindings_revoked_after_assigned",
    )
  end

  def down
    remove_check_constraint(:avatar_agent_bindings, name: "chk_avatar_agent_bindings_revoked_after_assigned")
    remove_check_constraint(:avatar_individual_bindings, name: "chk_avatar_individual_bindings_revoked_after_assigned")

    remove_index(:avatar_agent_bindings, name: "index_avatar_agent_bindings_on_public_id", if_exists: true, algorithm: :concurrently)
    remove_index(:avatar_individual_bindings, name: "index_avatar_individual_bindings_on_public_id", if_exists: true, algorithm: :concurrently)

    restore_bare_unique_indexes(
      :avatar_agent_bindings,
      :agent_id,
      active_pair: "idx_avatar_agent_bindings_active_pair",
      active_avatar: "idx_avatar_agent_bindings_active_avatar",
      active_subject: "idx_avatar_agent_bindings_active_agent",
    )
    restore_bare_unique_indexes(
      :avatar_individual_bindings,
      :individual_id,
      active_pair: "idx_avatar_individual_bindings_active_pair",
      active_avatar: "idx_avatar_individual_bindings_active_avatar",
      active_subject: "idx_avatar_individual_bindings_active_individual",
    )

    remove_column(:avatar_agent_bindings, :revoked_at, if_exists: true)
    remove_column(:avatar_agent_bindings, :assigned_at, if_exists: true)
    remove_column(:avatar_agent_bindings, :public_id, if_exists: true)
    remove_column(:avatar_individual_bindings, :revoked_at, if_exists: true)
    remove_column(:avatar_individual_bindings, :assigned_at, if_exists: true)
    remove_column(:avatar_individual_bindings, :public_id, if_exists: true)
  end

  private

  def add_lifecycle_columns(table_name)
    add_column(table_name, :public_id, :string, limit: 21) unless column_exists?(table_name, :public_id)
    add_column(table_name, :assigned_at, :datetime) unless column_exists?(table_name, :assigned_at)
    add_column(table_name, :revoked_at, :datetime) unless column_exists?(table_name, :revoked_at)
  end

  def backfill_lifecycle_columns(model_class)
    model_class.reset_column_information
    backfill_time = Time.current

    model_class.where(public_id: nil).find_each do |binding|
      binding.update_columns(public_id: next_public_id(model_class))
    end

    model_class.where(assigned_at: nil).find_each do |binding|
      binding.update_columns(assigned_at: binding.created_at || backfill_time)
    end
  end

  def next_public_id(model_class)
    loop do
      public_id = Nanoid.generate(size: 21)
      return public_id unless model_class.exists?(public_id: public_id)
    end
  end

  def assert_no_active_uniqueness_violations(model_class, subject_column)
    duplicate_avatar_ids = model_class.where(revoked_at: nil).group(:avatar_id).having("COUNT(*) > 1").limit(5).count.keys
    duplicate_subject_ids = model_class.where(revoked_at: nil).group(subject_column).having("COUNT(*) > 1").limit(5).count.keys
    duplicate_pairs =
      model_class
        .where(revoked_at: nil)
        .group(:avatar_id, subject_column)
        .having("COUNT(*) > 1")
        .limit(5)
        .count
        .keys

    return if duplicate_avatar_ids.empty? && duplicate_subject_ids.empty? && duplicate_pairs.empty?

    raise ActiveRecord::IrreversibleMigration,
          "#{model_class.table_name} has active binding uniqueness violations: " \
          "avatar_ids=#{duplicate_avatar_ids.inspect}, " \
          "#{subject_column}s=#{duplicate_subject_ids.inspect}, " \
          "pairs=#{duplicate_pairs.inspect}"
  end

  def replace_bare_unique_indexes(table_name, subject_column, active_pair:, active_avatar:, active_subject:)
    add_index(
      table_name,
      [:avatar_id, subject_column],
      unique: true,
      where: "revoked_at IS NULL",
      name: active_pair,
      if_not_exists: true,
      algorithm: :concurrently,
    )
    add_index(
      table_name,
      :avatar_id,
      unique: true,
      where: "revoked_at IS NULL",
      name: active_avatar,
      if_not_exists: true,
      algorithm: :concurrently,
    )
    add_index(
      table_name,
      subject_column,
      unique: true,
      where: "revoked_at IS NULL",
      name: active_subject,
      if_not_exists: true,
      algorithm: :concurrently,
    )

    remove_index(table_name, name: "index_#{table_name}_on_avatar_id", if_exists: true, algorithm: :concurrently)
    remove_index(table_name, name: "index_#{table_name}_on_#{subject_column}", if_exists: true, algorithm: :concurrently)
    add_index(table_name, :avatar_id, if_not_exists: true, algorithm: :concurrently)
    add_index(table_name, subject_column, if_not_exists: true, algorithm: :concurrently)
  end

  def restore_bare_unique_indexes(table_name, subject_column, active_pair:, active_avatar:, active_subject:)
    remove_index(table_name, name: active_pair, if_exists: true, algorithm: :concurrently)
    remove_index(table_name, name: active_avatar, if_exists: true, algorithm: :concurrently)
    remove_index(table_name, name: active_subject, if_exists: true, algorithm: :concurrently)
    remove_index(table_name, name: "index_#{table_name}_on_avatar_id", if_exists: true, algorithm: :concurrently)
    remove_index(table_name, name: "index_#{table_name}_on_#{subject_column}", if_exists: true, algorithm: :concurrently)
    add_index(table_name, :avatar_id, unique: true, if_not_exists: true, algorithm: :concurrently)
    add_index(table_name, subject_column, unique: true, if_not_exists: true, algorithm: :concurrently)
  end

  def add_revoked_ordering_constraint(table_name, constraint_name)
    return if check_constraint_exists?(table_name, name: constraint_name)

    add_check_constraint(
      table_name,
      "revoked_at IS NULL OR revoked_at >= assigned_at",
      name: constraint_name,
      validate: false,
    )
  end

  def add_not_null_constraint(table_name, column_name)
    constraint_name = "#{table_name}_#{column_name}_not_null"
    return if check_constraint_exists?(table_name, name: constraint_name)

    add_check_constraint(
      table_name,
      "#{column_name} IS NOT NULL",
      name: constraint_name,
      validate: false,
    )
  end
end
