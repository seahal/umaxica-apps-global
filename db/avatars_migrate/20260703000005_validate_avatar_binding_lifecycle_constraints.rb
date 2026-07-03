# frozen_string_literal: true

class ValidateAvatarBindingLifecycleConstraints < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  NOT_NULL_CONSTRAINTS = {
    avatar_agent_bindings: %i[public_id assigned_at],
    avatar_individual_bindings: %i[public_id assigned_at],
  }.freeze

  def up
    validate_not_null_constraints
    enforce_not_null_columns

    validate_check_constraint(:avatar_agent_bindings, name: "chk_avatar_agent_bindings_revoked_after_assigned")
    validate_check_constraint(:avatar_individual_bindings, name: "chk_avatar_individual_bindings_revoked_after_assigned")
  end

  def down
    NOT_NULL_CONSTRAINTS.each do |table_name, column_names|
      column_names.each do |column_name|
        change_column_null(table_name, column_name, true)
      end
    end
  end

  private

  def validate_not_null_constraints
    NOT_NULL_CONSTRAINTS.each do |table_name, column_names|
      column_names.each do |column_name|
        validate_check_constraint(table_name, name: not_null_constraint_name(table_name, column_name))
      end
    end
  end

  def enforce_not_null_columns
    safety_assured do
      NOT_NULL_CONSTRAINTS.each do |table_name, column_names|
        column_names.each do |column_name|
          change_column_null(table_name, column_name, false)
          remove_check_constraint(table_name, name: not_null_constraint_name(table_name, column_name))
        end
      end
    end
  end

  def not_null_constraint_name(table_name, column_name)
    "#{table_name}_#{column_name}_not_null"
  end
end
