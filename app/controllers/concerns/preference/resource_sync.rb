# typed: false
# frozen_string_literal: true

module Preference
  module ResourceSync
    extend ActiveSupport::Concern

    private

    def sync_to_resource_preference!
      return unless respond_to?(:current_resource, true)

      resource = preference_current_resource
      return if resource.blank?

      resource_pref = preference_write_resource_preference!(resource)
      return if resource_pref.blank?

      authorize!(resource_pref, to: :update?) if respond_to?(:authorize!, true)
      sync_direct_resource_preference!(resource_pref)
    rescue Preference::ResolutionError
      raise
    rescue StandardError => e
      Rails.logger.info(LogEvent.format("preference.sync_to_resource.error", error: e.class.name, message: e.message))
    end

    def preference_write_resource_preference!(resource = nil)
      resource ||= preference_current_resource if respond_to?(:current_resource, true)
      return if resource.blank?

      case preference_class.name
      when "AppPreference"
        resource.user_preference || create_resource_preference_for_write!(ClientPreference, :user_id, resource.id)
      when "OrgPreference"
        resource.staff_preference || create_resource_preference_for_write!(OperatorPreference, :staff_id, resource.id)
      when "ComPreference"
        resource.visitor_preference || create_resource_preference_for_write!(
          VisitorPreference, :visitor_id,
          resource.id,
        )
      end
    end

    def create_resource_preference_for_write!(preference_model, foreign_key, resource_id)
      connection_class = preference_connection_class(preference_model)
      preference = nil

      connection_class.connected_to(role: :writing) do
        preference = preference_model.create!(foreign_key => resource_id)
        create_resource_preference_children_for_write!(preference)
      end

      preference
    end

    def create_resource_preference_children_for_write!(resource_pref)
      prefix = resource_preference_registry_prefix(resource_pref)
      Preference::ClassRegistry::CHILD_RECORD_TYPES.each do |type|
        Preference::ClassRegistry.option_class(prefix, type).ensure_defaults!
        Preference::ClassRegistry.record_class(prefix, type).create!(
          preference: resource_pref,
          option_id: Preference::ClassRegistry.default_option_id(prefix, type),
        )
      end
    end

    def authorize_resource_preference_write!(resource_pref)
      authorize!(resource_pref, to: :update?) if resource_pref.present? && respond_to?(:authorize!, true)
    end

    def write_resource_preference_option!(resource_pref, type, shared_option_id)
      return if resource_pref.blank? || shared_option_id.blank?

      type = Preference::ClassRegistry::TYPE_KEY_MAP.fetch(type, type).to_sym
      resource_prefix = resource_preference_registry_prefix(resource_pref)
      direct_value = resource_preference_value_for_option(preference_prefix, type, shared_option_id)
      resource_option_id = mapped_resource_option_id(resource_prefix, type, shared_option_id)
      direct_value = resource_preference_value_for_option(
        resource_prefix, type,
        resource_option_id,
      ) if resource_option_id.present?
      return if resource_option_id.blank? && direct_value.blank?

      attrs = {}
      attrs[type] = direct_value if direct_value.present? && resource_pref.respond_to?(:"#{type}=")

      preference_connection_class(resource_pref.class).connected_to(role: :writing) do
        if resource_option_id.present?
          child = load_or_create_resource_preference_child!(resource_pref, resource_prefix, type)
          child&.update!(option_id: resource_option_id)
        end
        resource_pref.update!(attrs.slice(*resource_pref.attribute_names.map(&:to_sym)))
      end
    end

    def write_resource_preference_cookie!(resource_pref, attrs)
      return if resource_pref.blank? || attrs.blank?

      allowed = attrs.to_h.with_indifferent_access.slice(
        :consented, :functional, :performant, :targetable, :consented_at,
      )
      return if allowed.blank?

      preference_connection_class(resource_pref.class).connected_to(role: :writing) do
        resource_pref.update!(allowed)
      end
    end

    def reset_resource_preference_defaults_for_write!(resource_pref)
      return if resource_pref.blank?

      resource_prefix = resource_preference_registry_prefix(resource_pref)
      association_prefix = resource_preference_association_prefix(resource_pref)

      preference_connection_class(resource_pref.class).connected_to(role: :writing) do
        Preference::ClassRegistry::CHILD_RECORD_TYPES.each do |type|
          Preference::ClassRegistry.option_class(resource_prefix, type).ensure_defaults!
          default_id = Preference::ClassRegistry.default_option_id(resource_prefix, type)
          association_name = "#{association_prefix}_#{type}"
          child = resource_pref.public_send(association_name) if resource_pref.respond_to?(association_name)
          child ||= load_or_create_resource_preference_child!(resource_pref, resource_prefix, type)
          child&.update!(option_id: default_id) if child.blank? || child.option_id != default_id

          direct_value = resource_preference_value_for_option(resource_prefix, type, default_id)
          resource_pref.public_send(
            :"#{type}=",
            direct_value,
          ) if direct_value.present? && resource_pref.respond_to?(:"#{type}=")
        end

        resource_pref.consented = false if resource_pref.respond_to?(:consented=)
        resource_pref.functional = false if resource_pref.respond_to?(:functional=)
        resource_pref.performant = false if resource_pref.respond_to?(:performant=)
        resource_pref.targetable = false if resource_pref.respond_to?(:targetable=)
        resource_pref.consented_at = nil if resource_pref.respond_to?(:consented_at=)
        resource_pref.save!
      end
    end

    def load_or_create_resource_preference_child!(resource_pref, resource_prefix, type)
      association_prefix = resource_preference_association_prefix(resource_pref)
      association_name = "#{association_prefix}_#{type}"
      create_name = "create_#{association_name}!"
      return unless resource_pref.respond_to?(association_name) || resource_pref.respond_to?(create_name)

      child = resource_pref.public_send("#{association_prefix}_#{type}")
      return child if child.present?
      return unless resource_pref.respond_to?(create_name)

      resource_pref.public_send(
        create_name,
        option_id: Preference::ClassRegistry.default_option_id(resource_prefix, type),
      )
    end

    def mapped_resource_option_id(resource_prefix, type, shared_option_id)
      Preference::ClassRegistry.option_class(resource_prefix, type).ensure_defaults!
      shared_option = Preference::ClassRegistry.option_class(preference_prefix, type).find_by(id: shared_option_id)
      return shared_option_id if shared_option.blank? || shared_option.name.blank?

      lookup_option_id(Preference::ClassRegistry.option_class(resource_prefix, type), shared_option.name)
    end

    def resource_preference_value_for_option(resource_prefix, type, option_id)
      case type
      when :language
        option_id_to_language(option_id, resource_prefix)
      when :region
        option_id_to_region(option_id, resource_prefix)
      when :timezone
        option_id_to_timezone(option_id, resource_prefix)
      when :theme
        normalize_colortheme(option_id_to_colortheme(option_id, resource_prefix))
      else
        option_id_to_preference_value(option_id, resource_prefix, type)
      end
    end

    def resource_preference_registry_prefix(resource_pref)
      case resource_pref
      when ClientPreference then "Client"
      when OperatorPreference then "Operator"
      when VisitorPreference then "Visitor"
      else
        resource_pref.class.name.delete_suffix("Preference")
      end
    end

    def resource_preference_association_prefix(resource_pref)
      case resource_pref
      when ClientPreference then "user_preference"
      when OperatorPreference then "staff_preference"
      when VisitorPreference then "visitor_preference"
      else
        resource_pref.class.name.underscore
      end
    end

    def preference_connection_class(model_or_class)
      model_class = model_or_class.is_a?(Class) ? model_or_class : model_or_class.class
      model_class.ancestors.find do |ancestor|
        ancestor.is_a?(Class) && ancestor < ActiveRecord::Base && ancestor.abstract_class?
      end || ActiveRecord::Base
    end

    def sync_direct_resource_preference!(resource_pref)
      snapshot = resolved_preference_snapshot(@preferences)
      cookie = resolved_preference_cookie(@preferences)
      attrs = snapshot.merge(cookie).compact
      return if attrs.blank?

      preference_connection_class(resource_pref.class).connected_to(role: :writing) { resource_pref.update!(attrs) }
    end

    def resolved_preference_snapshot(preference)
      return {} if preference.blank?

      if preference.respond_to?(:language) &&
          preference.respond_to?(:region) &&
          preference.respond_to?(:timezone) &&
          preference.respond_to?(:theme)
        return Preference::ClassRegistry::CHILD_RECORD_TYPES.each_with_object({}) do |type, snapshot|
          next unless preference.respond_to?(type)

          snapshot[type] = preference.public_send(type)
        end.compact
      end

      association_prefix = preference.class.name.underscore

      Preference::ClassRegistry::CHILD_RECORD_TYPES.each_with_object({}) do |type, snapshot|
        child = preference.public_send("#{association_prefix}_#{type}")
        value = child&.option&.name
        value = value&.downcase if %i(language region currency).include?(type)
        value = colortheme_short_code(value) if type == :theme
        snapshot[type] = value if value.present?
      end
    end

    def resolved_preference_cookie(preference)
      return default_preference_cookie_state if preference.blank?

      if preference.respond_to?(:consented)
        return {
          consented: !!preference.consented,
          functional: !!preference.functional,
          performant: !!preference.performant,
          targetable: !!preference.targetable,
        }
      end

      association_prefix = preference.class.name.underscore
      cookie = preference.public_send("#{association_prefix}_cookie")
      return default_preference_cookie_state if cookie.blank?

      {
        consented: !!cookie.consented,
        functional: !!cookie.functional,
        performant: !!cookie.performant,
        targetable: !!cookie.targetable,
      }
    end

    def default_preference_cookie_state
      {
        consented: false,
        functional: false,
        performant: false,
        targetable: false,
      }
    end
  end
end
