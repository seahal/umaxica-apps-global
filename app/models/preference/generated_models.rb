# typed: false
# frozen_string_literal: true

module Preference
  module GeneratedModels
    module_function

    TYPES = {
      currency: {
        suffix: "Currency",
        plural: "currencies",
        constants: { NOTHING: 0, USD: 1, JPY: 2 },
        names: { 1 => "usd", 2 => "jpy" },
        default: :JPY,
      },
      date_format: {
        suffix: "DateFormat",
        plural: "date_formats",
        constants: { NOTHING: 0, ISO: 1, UK: 2, US: 3 },
        names: { 1 => "iso", 2 => "uk", 3 => "us" },
        default: :ISO,
      },
      time_format: {
        suffix: "TimeFormat",
        plural: "time_formats",
        constants: { NOTHING: 0, HOUR_24: 1, HOUR_12: 2 },
        names: { 1 => "hour_24", 2 => "hour_12" },
        default: :HOUR_24,
      },
      motion: {
        suffix: "Motion",
        plural: "motions",
        constants: { NOTHING: 0, STANDARD: 1, REDUCED: 2 },
        names: { 1 => "standard", 2 => "reduced" },
        default: :STANDARD,
      },
      density: {
        suffix: "Density",
        plural: "densities",
        constants: { NOTHING: 0, STANDARD: 1, COMPACT: 2 },
        names: { 1 => "standard", 2 => "compact" },
        default: :STANDARD,
      },
      items_per_page: {
        suffix: "ItemsPerPage",
        plural: "items_per_pages",
        constants: { NOTHING: 0, PER_10: 1, PER_20: 2, PER_50: 3, PER_100: 4 },
        names: { 1 => "10", 2 => "20", 3 => "50", 4 => "100" },
        default: :PER_20,
      },
    }.freeze

    PREFIXES = {
      "App" => { base: AppSettingRecord, parent: AppPreference },
      "Client" => { base: AppPrincipalRecord, parent: ClientPreference, table_prefix: "user" },
      "Org" => { base: OrgSettingRecord, parent: OrgPreference },
      "Operator" => { base: OrgPrincipalRecord, parent: OperatorPreference, table_prefix: "staff" },
      "Com" => { base: ComSettingRecord, parent: ComPreference },
      "Visitor" => { base: ComPrincipalRecord, parent: VisitorPreference },
    }.freeze

    def install!
      PREFIXES.each do |prefix, config|
        TYPES.each do |type, metadata|
          define_option_class(prefix, config, type, metadata)
          define_record_class(prefix, config, type, metadata)
          define_parent_association(prefix, config, type, metadata)
        end
      end
    end

    def define_option_class(prefix, config, type, metadata)
      class_name = "#{prefix}Preference#{metadata.fetch(:suffix)}Option"
      return if Object.const_defined?(class_name)

      base_class = config.fetch(:base)
      child_class_name = "#{prefix}Preference#{metadata.fetch(:suffix)}"
      child_association = "#{prefix.underscore}_preference_#{metadata.fetch(:plural)}"
      table_prefix = config.fetch(:table_prefix, prefix.underscore)
      table_name = "#{table_prefix}_preference_#{type}_options"
      constants = metadata.fetch(:constants)
      names = metadata.fetch(:names)

      option_class =
        Class.new(base_class) do
          include ReferenceRecord

          self.table_name = table_name

          constants.each { |constant_name, value| const_set(constant_name, value) }

          has_many child_association.to_sym,
                   class_name: child_class_name,
                   foreign_key: :option_id,
                   inverse_of: :option,
                   dependent: :restrict_with_error

          define_method(:name) do
            names[id]
          end

          const_set(:DEFAULTS, constants.values.freeze)

          define_singleton_method(:ensure_defaults!) do
            insert_missing_fixed_ids!(constants.values)
          end
        end

      Object.const_set(class_name, option_class)
    end

    def define_record_class(prefix, config, type, metadata)
      class_name = "#{prefix}Preference#{metadata.fetch(:suffix)}"
      return if Object.const_defined?(class_name)

      base_class = config.fetch(:base)
      parent_class = config.fetch(:parent)
      option_class_name = "#{prefix}Preference#{metadata.fetch(:suffix)}Option"
      default_option_id = metadata.fetch(:constants).fetch(metadata.fetch(:default))
      child_association = "#{prefix.underscore}_preference_#{type}"
      option_association = "#{prefix.underscore}_preference_#{metadata.fetch(:plural)}"
      table_prefix = config.fetch(:table_prefix, prefix.underscore)
      table_name = "#{table_prefix}_preference_#{metadata.fetch(:plural)}"

      record_class =
        Class.new(base_class) do
          self.table_name = table_name

          belongs_to :preference,
                     class_name: parent_class.name,
                     inverse_of: child_association.to_sym
          belongs_to :option,
                     class_name: option_class_name,
                     inverse_of: option_association.to_sym

          validates :preference_id, uniqueness: true
          before_validation :set_option_id

          define_method(:set_option_id) do
            self.option_id ||= default_option_id
          end

          private :set_option_id
        end

      Object.const_set(class_name, record_class)
    end

    def define_parent_association(prefix, config, type, metadata)
      parent_class = config.fetch(:parent)
      association = :"#{prefix.underscore}_preference_#{type}"
      return if parent_class.reflect_on_association(association)

      parent_class.has_one association,
                           class_name: "#{prefix}Preference#{metadata.fetch(:suffix)}",
                           foreign_key: :preference_id,
                           inverse_of: :preference,
                           dependent: :destroy
    end
  end
end

Preference::GeneratedModels.install!
