# typed: false
# frozen_string_literal: true

module Preference
  module Adoption
    extend ActiveSupport::Concern

    CHILD_RECORD_TYPES = Preference::ClassRegistry::CHILD_RECORD_TYPES
    COOKIE_CONSENT_FIELDS = %i(consented functional performant targetable).freeze

    private

    # Called after login to sync preferences between AppPreference/OrgPreference
    # and UserPreference/OperatorPreference. Uses updated_at to determine which is newer.
    # Non-fatal: never blocks login on failure.
    def adopt_preference_for!(resource)
      return unless adoptable_preference_class?
      return if resource.blank? || @preferences.blank?

      resource_pref = find_or_create_resource_preference!(resource)
      return if resource_pref.blank?

      sync_preferences!(resource_pref)
    rescue StandardError => e
      Rails.event.record("preference.adoption.error", error: e.class.name, message: e.message)
    end

    # Called during preference rotation to keep UserPreference/OperatorPreference in sync.
    # Non-fatal: never blocks rotation on failure.
    def adopt_rotated_preference!(resource, new_preference)
      return unless adoptable_preference_class?
      return if resource.blank? || new_preference.blank?

      @preferences = new_preference
      resource_pref = find_resource_preference(resource)
      return if resource_pref.blank?

      copy_preference_values!(@preferences, resource_pref, resource_pref_prefix)
    rescue StandardError => e
      Rails.event.record("preference.adoption.rotation_error", error: e.class.name, message: e.message)
    end

    def adoptable_preference_class?
      name = preference_class.name
      name == "AppPreference" || name == "OrgPreference"
    end

    # Find or create the 1:1 UserPreference/OperatorPreference for this resource.
    def find_or_create_resource_preference!(resource)
      pref = find_resource_preference(resource)
      return pref if pref.present?

      create_resource_preference!(resource)
    end

    def find_resource_preference(resource)
      case preference_class.name
      when "AppPreference"
        resource.user_preference
      when "OrgPreference"
        resource.staff_preference
      end
    end

    def create_resource_preference!(resource)
      pref_class, fk = resource_preference_mapping
      return nil unless pref_class

      pref = nil
      connection_class = pref_class.ancestors.find { |ancestor| ancestor.is_a?(Class) && ancestor < ActiveRecord::Base && ancestor.abstract_class? }
      connection_class.connected_to(role: :writing) do
        pref = pref_class.create!(fk => resource.id)
        create_resource_preference_options!(pref)
      end
      pref
    end

    def create_resource_preference_options!(resource_pref)
      prefix = resource_pref_prefix
      CHILD_RECORD_TYPES.each do |type|
        Preference::ClassRegistry.option_class(prefix, type).ensure_defaults!
        Preference::ClassRegistry.record_class(prefix, type).create!(
          preference: resource_pref,
          option_id: Preference::ClassRegistry.default_option_id(prefix, type),
        )
      end
    end

    # Compare updated_at and sync in the appropriate direction.
    def sync_preferences!(resource_pref)
      app_updated = @preferences.updated_at
      res_updated = resource_pref.updated_at

      if res_updated.present? && (app_updated.blank? || res_updated > app_updated)
        # UserPreference/OperatorPreference is newer; copy to AppPreference/OrgPreference.
        copy_preference_values!(resource_pref, @preferences, preference_prefix)
        issue_access_token_from(@preferences)
      else
        # AppPreference/OrgPreference is newer; copy to UserPreference/OperatorPreference.
        copy_preference_values!(@preferences, resource_pref, resource_pref_prefix)
        issue_access_token_from(@preferences)
      end
    end

    # Copy child record option_ids and cookie consent from source to target.
    def copy_preference_values!(source, target, target_prefix)
      source_assoc = source.class.name.underscore
      target_assoc = target.class.name.underscore

      CHILD_RECORD_TYPES.each do |type|
        source_child = source.public_send("#{source_assoc}_#{type}")
        next unless source_child&.option_id

        target_child = target.public_send("#{target_assoc}_#{type}") ||
          begin
            Preference::ClassRegistry.option_class(target_prefix, type).ensure_defaults!
            target.public_send(
              "create_#{target_assoc}_#{type}!",
              option_id: Preference::ClassRegistry.default_option_id(target_prefix, type),
            )
          end

        if target_child.option_id != source_child.option_id
          target_option_class = Preference::ClassRegistry.option_class(target_prefix, type)
          # Map option by name since option IDs may differ across databases
          resolved_id = resolve_cross_db_option_id(source_child, target_option_class)
          next unless resolved_id

          connection_class = target.class.ancestors.find { |a| a.is_a?(Class) && a < ActiveRecord::Base && a.abstract_class? }
          if connection_class
            connection_class.connected_to(role: :writing) { target_child.update!(option_id: resolved_id) }
          else
            target_child.update!(option_id: resolved_id)
          end
        end
      end

      copy_flat_preference_values!(source, target)
      copy_cookie_consent!(source, target, source_assoc, target_assoc)
      touch_target!(target)
    end

    def resolve_cross_db_option_id(source_child, target_option_class)
      source_option = source_child.option
      return source_child.option_id if source_option.blank?

      source_name = source_option.name
      return source_child.option_id if source_name.blank?

      target_option_class.find_each do |opt|
        return opt.id if opt.name&.downcase == source_name.downcase
      end
      nil
    end

    def copy_cookie_consent!(source, target, _source_assoc, _target_assoc)
      if source.respond_to?(:consented)
        # Source is UserPreference/OperatorPreference (direct columns)
        source_consent = COOKIE_CONSENT_FIELDS.index_with { |f| source.public_send(f) }
      else
        source_assoc_name = source.class.name.underscore
        source_cookie = source.public_send("#{source_assoc_name}_cookie")
        return unless source_cookie

        source_consent = COOKIE_CONSENT_FIELDS.index_with { |f| source_cookie.public_send(f) }
      end

      if target.respond_to?(:consented)
        # Target is UserPreference/OperatorPreference (direct columns)
        connection_class = target.class.ancestors.find { |a| a.is_a?(Class) && a < ActiveRecord::Base && a.abstract_class? }
        if connection_class
          connection_class.connected_to(role: :writing) { target.update!(source_consent) }
        else
          target.update!(source_consent)
        end
      else
        target_assoc_name = target.class.name.underscore
        target_cookie = target.public_send("#{target_assoc_name}_cookie") ||
          target.public_send("create_#{target_assoc_name}_cookie!")
        connection_class = target.class.ancestors.find { |a| a.is_a?(Class) && a < ActiveRecord::Base && a.abstract_class? }
        if connection_class
          connection_class.connected_to(role: :writing) { target_cookie.update!(source_consent) }
        else
          target_cookie.update!(source_consent)
        end
      end
    end

    def copy_flat_preference_values!(source, target)
      return unless target.respond_to?(:language=)

      snapshot = preference_snapshot_for(source)
      return if snapshot.blank?

      connection_class = target.class.ancestors.find { |a| a.is_a?(Class) && a < ActiveRecord::Base && a.abstract_class? }
      if connection_class
        connection_class.connected_to(role: :writing) { target.update!(snapshot) }
      else
        target.update!(snapshot)
      end
    end

    def preference_snapshot_for(preference)
      return if preference.blank?

      if local_preference_snapshot_source?(preference)
        return CHILD_RECORD_TYPES.each_with_object({}) do |type, snapshot|
          next unless preference.respond_to?(type)

          snapshot[type] = preference.public_send(type)
        end.compact
      end

      association_prefix = preference.class.name.underscore

      CHILD_RECORD_TYPES.each_with_object({}) do |type, snapshot|
        child = preference.public_send("#{association_prefix}_#{type}")
        value = child&.option&.name
        value = value&.downcase if %i(language region currency).include?(type)
        value = preference_theme_short_code(value) if type == :theme
        snapshot[type] = value if value.present?
      end
    end

    def local_preference_snapshot_source?(preference)
      preference.respond_to?(:language) &&
        preference.respond_to?(:region) &&
        preference.respond_to?(:timezone) &&
        preference.respond_to?(:theme)
    end

    def preference_theme_short_code(value)
      case value.to_s.downcase
      when "light", "li"
        "li"
      when "dark", "dr"
        "dr"
      when "system", "sy"
        "sy"
      end
    end

    def touch_target!(target)
      connection_class = target.class.ancestors.find { |a| a.is_a?(Class) && a < ActiveRecord::Base && a.abstract_class? }
      if connection_class
        connection_class.connected_to(role: :writing) { target.update!(updated_at: Time.current) }
      else
        target.update!(updated_at: Time.current)
      end
    end

    def resource_preference_mapping
      case preference_class.name
      when "AppPreference"
        [UserPreference, :user_id]
      when "OrgPreference"
        [OperatorPreference, :staff_id]
      else
        [nil, nil]
      end
    end

    def resource_pref_prefix
      case preference_class.name
      when "AppPreference" then "User"
      when "OrgPreference" then "Operator"
      end
    end
  end
end
