# frozen_string_literal: true

# Replaces the database_consistency gem (v3.0.5), which fails on this app because it calls
# the deprecated ActiveRecord::Base.connection and the app treats deprecations as exceptions.
#
# Implements all 22 checkers using connection_pool.with_connection (multi-DB aware, no deprecated API).
#
# Usage:
#   bin/rails db:consistency:check
#   bin/rails db:consistency:check CHECKERS=NullConstraintChecker,MissingIndexChecker
#   bin/rails db:consistency:check VERBOSE=1

namespace :db do
  namespace :consistency do
    desc "Run database consistency checks (replacement for database_consistency gem)"
    task check: :environment do
      DbConsistencyCheckRunner.new(
        checker_filter: ENV["CHECKERS"],
        verbose: ENV["VERBOSE"].present?,
      ).run
    end
  end
end

class DbConsistencyCheckRunner
  FRAMEWORK_PREFIXES = %w(
    ActionMailbox:: ActionText:: ActiveStorage::
    ActionPushNative:: SolidQueue::
  ).freeze

  STATUS_COLORS = { fail: "\e[31m", warn: "\e[33m", ok: "\e[32m", reset: "\e[0m" }.freeze

  def initialize(checker_filter: nil, verbose: false)
    @checker_filter = checker_filter&.split(",")&.map(&:strip)
    @verbose = verbose
  end

  def run
    eager_load_with_warnings
    models = collect_models
    db_names = models.map { |m| m.connection_db_config.name rescue "?" }
    db_names.uniq!
    db_count = db_names.size
    puts "Checking #{models.size} models across #{db_count} databases..."
    puts ""

    results = run_all_checkers(models)
    print_results(results)

    fail_count = results.count { |r| r[:status] == :fail }
    warn_count = results.count { |r| r[:status] == :warn }
    puts ""
    puts "Results: #{fail_count} failures, #{warn_count} warnings"
    exit(1) if fail_count > 0
  end

  private

  def eager_load_with_warnings
    Rails.application.eager_load!
  rescue => e
    warn(
      I18n.t(
        "db_consistency_check.eager_load_warning",
        klass: e.class,
        msg: e.message,
        default: "WARNING: eager_load! encountered an error (%{klass}: %{msg})" \
                 ". Results may be incomplete -- some models were not loaded.",
      ),
    )
  end

  def collect_models
    ApplicationRecord.descendants.reject do |m|
      m.abstract_class? ||
        m.name.blank? ||
        FRAMEWORK_PREFIXES.any? { |prefix| m.name.start_with?(prefix) }
    end.sort_by(&:name)
  end

  def all_checker_classes
    [
      DbConsistencyCheckers::MissingTableChecker,
      DbConsistencyCheckers::MissingAssociationClassChecker,
      DbConsistencyCheckers::ViewPrimaryKeyChecker,
      DbConsistencyCheckers::NullConstraintChecker,
      DbConsistencyCheckers::ColumnPresenceChecker,
      DbConsistencyCheckers::LengthConstraintChecker,
      DbConsistencyCheckers::ThreeStateBooleanChecker,
      DbConsistencyCheckers::MissingUniqueIndexChecker,
      DbConsistencyCheckers::UniqueIndexChecker,
      DbConsistencyCheckers::MissingIndexChecker,
      DbConsistencyCheckers::ForeignKeyChecker,
      DbConsistencyCheckers::ForeignKeyTypeChecker,
      DbConsistencyCheckers::ForeignKeyCascadeChecker,
      DbConsistencyCheckers::MissingDependentDestroyChecker,
      DbConsistencyCheckers::PrimaryKeyTypeChecker,
      DbConsistencyCheckers::RedundantIndexChecker,
      DbConsistencyCheckers::RedundantUniqueIndexChecker,
      DbConsistencyCheckers::EnumTypeChecker,
      DbConsistencyCheckers::EnumValueChecker,
      DbConsistencyCheckers::CaseSensitiveUniqueValidationChecker,
      DbConsistencyCheckers::ImplicitOrderingChecker,
      DbConsistencyCheckers::MissingIndexFindByChecker,
    ]
  end

  def run_all_checkers(models)
    checkers = all_checker_classes
    if @checker_filter
      checkers = checkers.select { |c| @checker_filter.include?(c.name.demodulize) }
    end
    checkers.flat_map do |klass|
      klass.new.check(models)
    rescue => e
      [{ status: :fail,
         model: klass.name.demodulize,
         column: "-",
         checker: klass.name.demodulize,
         message: "Checker crashed: #{e.message}", }]
    end
  end

  def print_results(results)
    rows = @verbose ? results : results.reject { |r| r[:status] == :ok }
    rows.sort_by { |r| [r[:model].to_s, r[:column].to_s, r[:checker].to_s] }.each do |r|
      color = STATUS_COLORS[r[:status]] || ""
      reset = STATUS_COLORS[:reset]
      status = "[#{r[:status]}]".ljust(6)
      puts "#{color}#{status}#{reset} #{r[:model]} #{r[:column]} #{r[:checker]} #{r[:message]}"
    end
  end
end

# ---------------------------------------------------------------------------
# Checkers
# ---------------------------------------------------------------------------

module DbConsistencyCheckers
  SKIP_COLUMNS_FOR_NULL_CHECK = %w(id created_at updated_at type).freeze

  module Helper
    # model.connection is deprecated in Rails 8 and raises ActiveSupport::DeprecationException
    # in this app (deprecations configured as exceptions). Use lease_connection instead.
    def with_model_connection(model)
      model.connection_pool.with_connection { |conn| yield conn }
    rescue
      yield nil
    end

    def table_accessible?(model)
      with_model_connection(model) { |conn| conn&.data_source_exists?(model.table_name) } || false
    end

    def accessible_models(models)
      models.select { |m| table_accessible?(m) }
    end

    def columns_for(model)
      with_model_connection(model) { |conn| conn&.columns(model.table_name) || [] }
    end

    def indexes_for(model)
      with_model_connection(model) { |conn| conn&.indexes(model.table_name) || [] }
    end

    def foreign_keys_for(model)
      with_model_connection(model) { |conn| conn&.foreign_keys(model.table_name) || [] }
    end

    def presence_validated_attributes(model)
      model.validators.flat_map do |validator|
        next [] unless presence_validator?(validator)
        next [] if conditional_presence_validator?(validator)

        validator.attributes.map(&:to_s)
      end.to_set
    end

    def belongs_to_fk_columns(model)
      model.reflect_on_all_associations(:belongs_to).map { |a| a.foreign_key.to_s }.to_set
    end

    def result(status, model:, column:, checker:, message:)
      { status: status, model: model.name, column: column.to_s, checker: checker, message: message }
    end

    def index_columns(index)
      Array(index.columns).map(&:to_s)
    end

    private

    def conditional_presence_validator?(validator)
      validator.options[:if].present? || validator.options[:unless].present?
    end

    def presence_validator?(validator)
      validator.is_a?(ActiveRecord::Validations::PresenceValidator) ||
        validator.is_a?(ActiveModel::Validations::PresenceValidator)
    end
  end

  # -------------------------------------------------------------------------
  # 1. MissingTableChecker -- model references a table/view that doesn't exist
  # -------------------------------------------------------------------------
  class MissingTableChecker
    include Helper

    CHECKER = "MissingTableChecker"

    def check(models)
      models.filter_map do |model|
        exists = with_model_connection(model) { |conn| conn&.data_source_exists?(model.table_name) }
        next if exists

        result(
          :fail, model: model, column: model.table_name, checker: CHECKER,
                 message: "table #{model.table_name} does not exist",
        )
      end
    end
  end

  # -------------------------------------------------------------------------
  # 2. MissingAssociationClassChecker -- association class can't be resolved
  # -------------------------------------------------------------------------
  class MissingAssociationClassChecker
    include Helper

    CHECKER = "MissingAssociationClassChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        model.reflect_on_all_associations.filter_map do |assoc|
          next if assoc.options[:polymorphic]

          assoc.klass
          nil
        rescue NameError => e
          result(
            :fail, model: model, column: assoc.name.to_s, checker: CHECKER,
                   message: "association class not found: #{e.message}",
          )
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # 3. ViewPrimaryKeyChecker -- DB view model has no primary_key declared
  # -------------------------------------------------------------------------
  class ViewPrimaryKeyChecker
    include Helper

    CHECKER = "ViewPrimaryKeyChecker"

    def check(models)
      accessible_models(models).filter_map do |model|
        views = with_model_connection(model) { |conn| conn.respond_to?(:views) ? conn.views : [] }
        next unless views.include?(model.table_name)
        next if model.primary_key.present?

        result(
          :warn, model: model, column: "primary_key", checker: CHECKER,
                 message: "view #{model.table_name} has no primary_key set on the model",
        )
      end
    end
  end

  # -------------------------------------------------------------------------
  # 4. NullConstraintChecker -- NOT NULL column without a presence validator
  # -------------------------------------------------------------------------
  class NullConstraintChecker
    include Helper

    CHECKER = "NullConstraintChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        presence_attrs = presence_validated_attributes(model)
        fk_cols = belongs_to_fk_columns(model)

        columns_for(model).filter_map do |col|
          next if SKIP_COLUMNS_FOR_NULL_CHECK.include?(col.name)
          next if col.null
          next if !col.default.nil? || col.default_function.present?
          # FK columns are validated implicitly by belongs_to (Rails 5+ default)
          next if fk_cols.include?(col.name)
          # Direct presence validation on the column name
          next if presence_attrs.include?(col.name)
          # Presence validation on a belongs_to association name for this FK
          next if association_presence_covers?(model, col.name)
          # Boolean inclusion validation is the correct non-nil contract for booleans.
          next if boolean_inclusion_covers?(model, col.name)

          result(
            :fail, model: model, column: col.name, checker: CHECKER,
                   message: "NOT NULL column has no presence validator",
          )
        end
      end
    end

    private

    def association_presence_covers?(model, col_name)
      model.reflect_on_all_associations(:belongs_to).any? do |assoc|
        assoc.foreign_key.to_s == col_name && !assoc.options[:optional]
      end
    end

    def boolean_inclusion_covers?(model, col_name)
      model.validators.any? do |validator|
        next false unless validator.is_a?(ActiveModel::Validations::InclusionValidator)
        next false unless validator.attributes.map(&:to_s).include?(col_name)

        expected = Array(validator.options[:in]).map(&:to_s).sort
        expected == %w(false true) && columns_for(model).any? { |col| col.name == col_name && col.type == :boolean }
      end
    end
  end

  # -------------------------------------------------------------------------
  # 5. ColumnPresenceChecker -- unconditional presence validator on a nullable column
  # -------------------------------------------------------------------------
  class ColumnPresenceChecker
    include Helper

    CHECKER = "ColumnPresenceChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        col_map = columns_for(model).index_by(&:name)
        presence_validated_attributes(model).filter_map do |attr|
          col = col_map[attr]
          next unless col
          next unless col.null

          result(
            :warn, model: model, column: attr, checker: CHECKER,
                   message: "presence validator on nullable column (consider adding NOT NULL constraint)",
          )
        end
      end
    end

  end

  # -------------------------------------------------------------------------
  # 6. LengthConstraintChecker -- length validator vs. column character limit
  # -------------------------------------------------------------------------
  class LengthConstraintChecker
    include Helper

    CHECKER = "LengthConstraintChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        col_map = columns_for(model).index_by(&:name)
        length_limits = length_validation_limits(model)

        col_map.values.filter_map do |col|
          next unless string_like_column?(col)

          db_limit = character_limit(col)
          next unless db_limit
          # Skip the default Rails varchar length to avoid flagging every plain string column.
          next if db_limit >= 255

          max_val = length_limits[col.name]
          if max_val.nil?
            result(
              :warn, model: model, column: col.name, checker: CHECKER,
                     message: "column limit (#{db_limit}) has no length validator",
            )
          elsif max_val > db_limit
            result(
              :fail, model: model, column: col.name, checker: CHECKER,
                     message: "length maximum (#{max_val}) exceeds column limit (#{db_limit})",
            )
          elsif max_val < db_limit
            result(
              :warn, model: model, column: col.name, checker: CHECKER,
                     message: "length maximum (#{max_val}) is stricter than " \
                              "column limit (#{db_limit}) -- consider tightening the constraint",
            )
          end
        end
      end
    end

    private

    def length_validation_limits(model)
      model.validators.each_with_object({}) do |validator, limits|
        next unless validator.is_a?(ActiveModel::Validations::LengthValidator)

        max = length_validator_maximum(validator)
        next unless max

        validator.attributes.each do |attr|
          attr_name = attr.to_s
          limits[attr_name] = [limits[attr_name], max].compact.min
        end
      end
    end

    def length_validator_maximum(validator)
      return validator.options[:maximum] if validator.options.key?(:maximum)
      return validator.options[:is] if validator.options.key?(:is)

      range = validator.options[:within] || validator.options[:in]
      return unless range.respond_to?(:max)

      range.max
    end

    def string_like_column?(col)
      sql_type = col.sql_type.to_s.downcase
      col.type == :string || sql_type.include?("char") || sql_type.include?("citext")
    end

    def character_limit(col)
      return col.limit if col.limit

      return unless col.sql_type =~ /character varying\((\d+)\)|varchar\((\d+)\)/i

      ($1 || $2).to_i

    end
  end

  # -------------------------------------------------------------------------
  # 7. ThreeStateBooleanChecker -- nullable boolean column
  # -------------------------------------------------------------------------
  class ThreeStateBooleanChecker
    include Helper

    CHECKER = "ThreeStateBooleanChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        columns_for(model).filter_map do |col|
          next unless col.type == :boolean
          next unless col.null

          result(
            :warn, model: model, column: col.name, checker: CHECKER,
                   message: "boolean column is nullable (three-state boolean: true/false/nil)",
          )
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # 8. MissingUniqueIndexChecker -- uniqueness validator without unique index
  # -------------------------------------------------------------------------
  class MissingUniqueIndexChecker
    include Helper

    CHECKER = "MissingUniqueIndexChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        indexes = indexes_for(model)
        pk_cols = Array(model.primary_key).map(&:to_s).to_set
        unique_validator_specs(model).filter_map do |col_names|
          next if col_names.to_set == pk_cols
          next if covered_by_unique_index?(indexes, col_names)

          result(
            :fail, model: model, column: col_names.join("+"), checker: CHECKER,
                   message: "uniqueness validator on (#{col_names.join(", ")}) has no unique index",
          )
        end
      end
    end

    private

    def unique_validator_specs(model)
      model.validators.flat_map do |v|
        next [] unless v.is_a?(ActiveRecord::Validations::UniquenessValidator)

        scope_cols = Array(v.options[:scope]).map(&:to_s)
        v.attributes.map { |attr| ([attr.to_s] + scope_cols).sort }
      end
    end

    def covered_by_unique_index?(indexes, col_names)
      target = col_names.to_set
      indexes.any? { |idx| idx.unique && index_columns(idx).to_set == target }
    end
  end

  # -------------------------------------------------------------------------
  # 9. UniqueIndexChecker -- unique index without uniqueness validator
  # -------------------------------------------------------------------------
  class UniqueIndexChecker
    include Helper

    CHECKER = "UniqueIndexChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        validated_sets = uniqueness_validated_col_sets(model)
        pk_cols = [model.primary_key.to_s]

        indexes_for(model).select(&:unique).filter_map do |idx|
          cols = index_columns(idx)
          cols.sort!
          next if cols == pk_cols
          next if cols.include?(model.primary_key.to_s)
          next if validated_sets.include?(cols.to_set)

          result(
            :warn, model: model, column: cols.join("+"), checker: CHECKER,
                   message: "unique index (#{cols.join(", ")}) has no corresponding uniqueness validator",
          )
        end
      end
    end

    private

    def uniqueness_validated_col_sets(model)
      model.validators.flat_map do |v|
        cols = uniqueness_validator_columns(v)
        next [] unless cols.any?

        scope_cols = Array(v.options[:scope]).map(&:to_s)
        cols.map { |attr| ([attr.to_s] + scope_cols).to_set }
      end
    end

    def uniqueness_validator_columns(validator)
      if validator.is_a?(ActiveRecord::Validations::UniquenessValidator)
        return validator.attributes
      end

      if defined?(BlindIndexUniquenessValidator) && validator.is_a?(BlindIndexUniquenessValidator)
        return Array(validator.attributes)
      end

      []
    end
  end

  # -------------------------------------------------------------------------
  # 10. MissingIndexChecker -- belongs_to FK without an index
  # -------------------------------------------------------------------------
  class MissingIndexChecker
    include Helper

    CHECKER = "MissingIndexChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        indexes = indexes_for(model)
        model.reflect_on_all_associations(:belongs_to).filter_map do |assoc|
          fk = assoc.foreign_key.to_s
          if assoc.options[:polymorphic]
            type_col = assoc.foreign_type.to_s
            # Acceptable: any index that covers both the type and id columns together
            next if indexes.any? { |idx|
              cols = index_columns(idx)
              cols.include?(fk) && cols.include?(type_col)
            }
          else
            next if indexes.any? { |idx| index_columns(idx).first == fk }
          end
          result(
            :warn, model: model, column: fk, checker: CHECKER,
                   message: "belongs_to :#{assoc.name} foreign key #{fk} has no index",
          )
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # 11. ForeignKeyChecker -- NOT NULL FK without a DB foreign key constraint
  # -------------------------------------------------------------------------
  class ForeignKeyChecker
    include Helper

    CHECKER = "ForeignKeyChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        col_map = columns_for(model).index_by(&:name)
        fk_constraint_cols = foreign_keys_for(model).map { |fk| fk.column.to_s }.to_set

        model.reflect_on_all_associations(:belongs_to).filter_map do |assoc|
          next if assoc.options[:polymorphic]

          fk = assoc.foreign_key.to_s
          col = col_map[fk]
          next unless col && !col.null
          next if fk_constraint_cols.include?(fk)

          result(
            :warn, model: model, column: fk, checker: CHECKER,
                   message: "belongs_to :#{assoc.name} has NOT NULL FK but no database foreign key constraint",
          )
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # 12. ForeignKeyTypeChecker -- FK column type mismatches referenced PK type
  # -------------------------------------------------------------------------
  class ForeignKeyTypeChecker
    include Helper

    CHECKER = "ForeignKeyTypeChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        col_map = columns_for(model).index_by(&:name)

        model.reflect_on_all_associations(:belongs_to).filter_map do |assoc|
          next if assoc.options[:polymorphic]

          fk = assoc.foreign_key.to_s
          fk_col = col_map[fk]
          next unless fk_col

          begin
            target = assoc.klass
          rescue NameError
            next
          end

          pk_accessible = with_model_connection(target) { |conn| conn&.data_source_exists?(target.table_name) }
          next unless pk_accessible

          pk_name = target.primary_key
          next unless pk_name

          pk_col =
            with_model_connection(target) { |conn|
              conn&.columns(target.table_name)&.find { |c|
                c.name == pk_name
              }
            }
          next unless pk_col
          next if normalized_sql_type(fk_col) == normalized_sql_type(pk_col)

          result(
            :fail, model: model, column: fk, checker: CHECKER,
                   message: "FK type #{fk_col.sql_type} doesn't match " \
                            "#{target.name}.#{pk_name} type #{pk_col.sql_type}",
          )
        end
      end
    end

    private

    def normalized_sql_type(col)
      sql = col.sql_type.downcase
      return :bigint  if sql.include?("bigint")
      return :integer if sql =~ /\bint\b/ || sql == "integer"
      return :uuid    if sql.include?("uuid")

      sql.to_sym
    end
  end

  # -------------------------------------------------------------------------
  # 13. ForeignKeyCascadeChecker -- DB FK constraint without on_delete action
  # -------------------------------------------------------------------------
  class ForeignKeyCascadeChecker
    include Helper

    CHECKER = "ForeignKeyCascadeChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        foreign_keys_for(model).filter_map do |fk|
          next if fk.on_delete.present?

          result(
            :warn, model: model, column: fk.column.to_s, checker: CHECKER,
                   message: "FK constraint on #{fk.column} → #{fk.to_table} has no on_delete action",
          )
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # 14. MissingDependentDestroyChecker -- has_many without dependent: when child FK is NOT NULL
  # -------------------------------------------------------------------------
  class MissingDependentDestroyChecker
    include Helper

    CHECKER = "MissingDependentDestroyChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        model.reflect_on_all_associations(:has_many).filter_map do |assoc|
          next if assoc.options[:dependent].present?
          next if assoc.options[:through].present?

          begin
            child = assoc.klass
          rescue NameError
            next
          end

          next unless with_model_connection(child) { |conn| conn&.data_source_exists?(child.table_name) }

          fk = assoc.foreign_key.to_s
          fk_col = with_model_connection(child) { |conn| conn&.columns(child.table_name)&.find { |c| c.name == fk } }
          next unless fk_col && !fk_col.null

          result(
            :warn, model: model, column: "#{assoc.name}/#{fk}", checker: CHECKER,
                   message: "has_many :#{assoc.name} -- child " \
                            "#{child.table_name}.#{fk} is NOT NULL but no dependent: option set",
          )
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # 15. PrimaryKeyTypeChecker -- PK is not bigint or uuid
  # -------------------------------------------------------------------------
  class PrimaryKeyTypeChecker
    include Helper

    CHECKER = "PrimaryKeyTypeChecker"

    def check(models)
      accessible_models(models).filter_map do |model|
        pk_name = model.primary_key
        next unless pk_name

        col = columns_for(model).find { |c| c.name == pk_name }
        next unless col

        sql = col.sql_type.downcase
        next if sql.include?("bigint") || sql.include?("uuid")

        result(
          :warn, model: model, column: pk_name, checker: CHECKER,
                 message: "primary key is #{col.sql_type} (expected bigint or uuid)",
        )
      end
    end
  end

  # -------------------------------------------------------------------------
  # 16. RedundantIndexChecker -- index whose columns are a prefix of another index
  # -------------------------------------------------------------------------
  class RedundantIndexChecker
    include Helper

    CHECKER = "RedundantIndexChecker"

    def check(models)
      deduplicate_by_table(models) do |model|
        detect_redundant(model, indexes_for(model), unique_only: false)
      end
    end

    private

    def deduplicate_by_table(models)
      seen = Set.new
      models.flat_map do |model|
        next [] if seen.include?(model.table_name)

        seen << model.table_name
        table_accessible?(model) ? yield(model) : []
      end
    end

    def detect_redundant(model, indexes, unique_only:)
      pool = unique_only ? indexes.select(&:unique) : indexes
      pool.filter_map do |idx|
        others = pool.reject { |o| o.name == idx.name }
        next unless others.any? { |other| strict_prefix?(index_columns(idx), index_columns(other)) }

        result(
          :warn, model: model, column: idx.name, checker: self.class::CHECKER,
                 message: "index #{idx.name} (#{index_columns(idx).join(", ")}) " \
                          "is redundant -- its columns are a prefix of another index",
        )
      end
    end

    def strict_prefix?(shorter, longer)
      return false if shorter.size >= longer.size

      prefix = longer.first(shorter.size)
      prefix.map!(&:to_s)
      prefix == shorter.map(&:to_s)
    end
  end

  # -------------------------------------------------------------------------
  # 17. RedundantUniqueIndexChecker -- unique index that is prefix of another unique index
  # -------------------------------------------------------------------------
  class RedundantUniqueIndexChecker < RedundantIndexChecker
    CHECKER = "RedundantUniqueIndexChecker"

    def check(models)
      deduplicate_by_table(models) do |model|
        detect_redundant(model, indexes_for(model), unique_only: true)
      end
    end
  end

  # -------------------------------------------------------------------------
  # 18. EnumTypeChecker -- Rails enum on a non-integer, non-string column
  # -------------------------------------------------------------------------
  class EnumTypeChecker
    include Helper

    CHECKER = "EnumTypeChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        next [] unless model.respond_to?(:defined_enums)

        col_map = columns_for(model).index_by(&:name)
        model.defined_enums.flat_map do |attr_name, _|
          col = col_map[attr_name]
          next [] unless col

          sql = col.sql_type.downcase
          next [] if sql.include?("int") || sql.include?("char") || sql.include?("text")

          [result(
            :fail, model: model, column: attr_name, checker: CHECKER,
                   message: "enum #{attr_name} is on #{col.sql_type} column (expected integer or string type)",
          )]
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # 19. EnumValueChecker -- enum values don't match DB check constraint
  # -------------------------------------------------------------------------
  class EnumValueChecker
    include Helper

    CHECKER = "EnumValueChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        next [] unless model.respond_to?(:defined_enums)

        constraints =
          with_model_connection(model) { |conn|
            conn&.respond_to?(:check_constraints) ? conn.check_constraints(model.table_name) : []
          }
        next [] if constraints.empty?

        col_map = columns_for(model).index_by(&:name)
        model.defined_enums.flat_map do |attr_name, mapping|
          col = col_map[attr_name]
          next [] unless col

          relevant = constraints.select { |c| c.expression.include?(attr_name) }
          next [] if relevant.empty?

          missing = mapping.keys.reject { |val| relevant.any? { |c| c.expression.include?(val.to_s) } }
          next [] if missing.empty?

          [result(
            :warn, model: model, column: attr_name, checker: CHECKER,
                   message: "enum value(s) #{missing.join(", ")} absent from check constraint expression",
          )]
        end
      rescue
        []
      end
    end
  end

  # -------------------------------------------------------------------------
  # 20. CaseSensitiveUniqueValidationChecker -- case-sensitive uniqueness on citext column
  # -------------------------------------------------------------------------
  class CaseSensitiveUniqueValidationChecker
    include Helper

    CHECKER = "CaseSensitiveUniqueValidationChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        col_map = columns_for(model).index_by(&:name)
        model.validators.flat_map do |v|
          next [] unless v.is_a?(ActiveRecord::Validations::UniquenessValidator)
          next [] if v.options.key?(:case_sensitive) && v.options[:case_sensitive] == false

          v.attributes.filter_map do |attr|
            col = col_map[attr.to_s]
            next unless col&.sql_type&.downcase&.include?("citext")

            result(
              :warn, model: model, column: attr.to_s, checker: CHECKER,
                     message: "uniqueness validator on citext column #{attr} should set case_sensitive: false",
            )
          end
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # 21. ImplicitOrderingChecker -- UUID-PK model with no default ordering
  # -------------------------------------------------------------------------
  class ImplicitOrderingChecker
    include Helper

    CHECKER = "ImplicitOrderingChecker"

    def check(models)
      accessible_models(models).filter_map do |model|
        pk_name = model.primary_key
        next unless pk_name

        col = columns_for(model).find { |c| c.name == pk_name }
        next unless col&.sql_type&.downcase&.include?("uuid")
        next if model_has_default_order?(model)

        result(
          :warn, model: model, column: pk_name, checker: CHECKER,
                 message: "model with UUID primary key has no default ordering (implicit order is non-deterministic)",
        )
      end
    end

    private

    def model_has_default_order?(model)
      model.default_scopes.any? do |scope|
        scope.respond_to?(:call) && scope.call.order_values.any?
      end
    rescue
      false
    end
  end

  # -------------------------------------------------------------------------
  # 22. MissingIndexFindByChecker -- dynamic find_by_* or named scope without index
  # -------------------------------------------------------------------------
  class MissingIndexFindByChecker
    include Helper

    CHECKER = "MissingIndexFindByChecker"

    def check(models)
      accessible_models(models).flat_map do |model|
        indexes = indexes_for(model)
        indexed_cols = indexes.flat_map(&:columns).map(&:to_s).to_set

        candidate_columns(model).filter_map do |col_name|
          next if supported_by_index?(model, col_name, indexed_cols)

          result(
            :warn, model: model, column: col_name, checker: CHECKER,
                   message: "find_by/scope pattern on #{col_name} has no supporting index",
          )
        end
      end
    end

    private

    def candidate_columns(model)
      col_names = columns_for(model).map(&:name).to_set
      return Set.new if col_names.empty?

      columns = Set.new
      # Rails dynamic finders: only those matching an actual column name.
      # model.methods includes find_by_sql, find_by_token_for etc. -- filter to real columns.
      model.methods.each do |m|
        col = m.to_s[/\Afind_by_([a-z_]+)\z/, 1]
        columns << col if col && col_names.include?(col)
      end
      # Named scopes with by_<column_name> convention in the source file
      scope_column_names(model).each { |c| columns << c if col_names.include?(c) }
      columns
    rescue
      Set.new
    end

    def scope_column_names(model)
      source_location = Object.const_source_location(model.name)&.first
      return [] unless source_location && File.exist?(source_location.to_s)

      File.read(source_location).scan(/scope\s+:by_([a-z_]+)/).flatten
    rescue
      []
    end

    def supported_by_index?(model, col_name, indexed_cols)
      return true if indexed_cols.include?(col_name)
      return true if model.respond_to?("find_by_#{col_name}") && indexed_cols.include?("#{col_name}_digest")

      false
    end
  end
end
