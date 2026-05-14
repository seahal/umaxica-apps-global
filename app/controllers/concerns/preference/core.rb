# typed: false
# frozen_string_literal: true

module Preference::Core
  extend ActiveSupport::Concern
  include Preference::Base

  included do
    before_action :ensure_preferences_record
  end

  COOKIE_EXPIRY = 400.days

  def set_region_preferences_edit
    with_preference_connection(:writing) do
      @preference_region = load_or_refresh_preference_child("Region", option_id: nil)
    end
  end

  def set_region_preferences_update
    with_preference_connection(:writing) do
      @preference_region = load_or_refresh_preference_child("Region", option_id: nil)

      update_preference_child_with_audit(
        @preference_region,
        sanitize_option_id(preference_region_params, option_type: :region),
        "UPDATE_PREFERENCE_REGION",
      )
      reload_preferences_and_reissue_token!
    end
  end

  def set_language_preferences_edit
    with_preference_connection(:writing) do
      @preference_language = load_or_refresh_preference_child("Language", option_id: nil)
    end
  end

  def set_language_preferences_update
    with_preference_connection(:writing) do
      @preference_language = load_or_refresh_preference_child("Language", option_id: nil)

      update_preference_child_with_audit(
        @preference_language,
        sanitize_option_id(preference_language_params, option_type: :language),
        "UPDATE_PREFERENCE_LANGUAGE",
      )
      reload_preferences_and_reissue_token!
    end

    return if @preference_language.option_id.blank?

    language = option_id_to_language(@preference_language.option_id, preference_prefix)
    write_preference_cookie(Preference::Base::LANGUAGE_COOKIE_KEY, language) if language.present?
  end

  def set_timezone_preferences_edit
    with_preference_connection(:writing) do
      @preference_timezone = load_or_refresh_preference_child("Timezone", option_id: nil)
    end

    timezone = option_id_to_timezone(@preference_timezone.option_id, preference_prefix)
    Time.zone = timezone if timezone.present?
  end

  def set_timezone_preferences_update
    raise PreferenceOperationError if @preferences.blank?

    submitted_timezone = preference_timezone_params[Preference::IoKeys::Params::OPTION_ID]

    with_preference_connection(:writing) do
      @preference_timezone = load_or_refresh_preference_child("Timezone", option_id: nil)

      begin
        update_preference_child_with_audit(
          @preference_timezone,
          sanitize_option_id(preference_timezone_params, option_type: :timezone),
          "UPDATE_PREFERENCE_TIMEZONE",
        )
        reload_preferences_and_reissue_token!
      rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ArgumentError
        raise PreferenceOperationError
      end
    end

    return if @preference_timezone.option_id.blank?

    @preference_timezone.reload
    timezone = option_id_to_timezone(@preference_timezone.option_id, preference_prefix)
    timezone = submitted_timezone if submitted_timezone.to_s.include?("/")
    Time.zone = timezone if timezone.present?
    session[:timezone] = timezone if timezone.present?
    write_preference_cookie(Preference::Base::TIMEZONE_COOKIE_KEY, timezone) if timezone.present?
  rescue ArgumentError
    raise PreferenceOperationError
  end

  def set_colortheme_preferences_edit
    with_preference_connection(:writing) do
      @preference_colortheme = load_or_refresh_preference_child("Colortheme", option_id: nil)
    end
  end

  def set_colortheme_preferences_update
    with_preference_connection(:writing) do
      @preference_colortheme = load_or_refresh_preference_child("Colortheme", option_id: nil)

      update_preference_child_with_audit(
        @preference_colortheme,
        sanitize_option_id(preference_colortheme_params, option_type: :colortheme),
        "UPDATE_PREFERENCE_COLORTHEME",
      )
      reload_preferences_and_reissue_token!
    end

    return if @preference_colortheme.option_id.blank?

    colortheme = option_id_to_colortheme(@preference_colortheme.option_id, preference_prefix)
    short_code = colortheme_short_code(colortheme)
    write_preference_cookie(Preference::Base::THEME_COOKIE_KEY, short_code) if short_code.present?
  end

  def set_selectable_preference_edit(type)
    @preference_option_type = type.to_sym
    with_preference_connection(:writing) do
      ensure_model_defaults!(Preference::ClassRegistry.option_class(preference_prefix, type))
      @preference_option = load_or_build_selectable_preference_child(type)
    end
  end

  def set_selectable_preference_update(type)
    type = type.to_sym
    @preference_option_type = type

    with_preference_connection(:writing) do
      ensure_model_defaults!(Preference::ClassRegistry.option_class(preference_prefix, type))
      @preference_option = load_or_refresh_preference_child(preference_child_class_suffix(type), option_id: nil)

      update_preference_child_with_audit(
        @preference_option,
        sanitize_option_id(selectable_preference_params(type), option_type: type),
        "UPDATE_PREFERENCE_#{type.to_s.upcase}",
      )
      reload_preferences_and_reissue_token!
    rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ArgumentError
      raise PreferenceOperationError
    end
  end

  def set_selectable_preference_view_context(type)
    @preference_option_type = type.to_sym
    @preference_surface_key = preference_surface_key
    @preference_option_scope = :"preference_#{type}"
    @preference_option_update_url = preference_update_url(type)
    @preference_option_choices =
      Preference::ClassRegistry.option_class(
        preference_prefix,
        type,
      ).order(:id).filter_map do |option|
        next if option.name.blank?

        [preference_option_label(type, option.name), option.id]
      end
    group_screen = preference_group_screen(type)
    @preference_option_back_url =
      if group_screen
        preference_edit_url(group_screen, preference_context_redirect_params)
      else
        preference_index_url(preference_context_redirect_params)
      end
  end

  def set_cookie_preferences_edit
    with_preference_connection(:writing) do
      @preference_cookie = load_or_refresh_preference_child(
        "Cookie",
        targetable: false, performant: false, functional: false, consented: false,
      )
    end
  end

  def set_cookie_preferences_update
    with_preference_connection(:writing) do
      @preference_cookie = load_or_refresh_preference_child(
        "Cookie",
        targetable: false, performant: false, functional: false, consented: false,
      )

      update_params = build_cookie_update_params(@preference_cookie, preference_cookie_params)

      update_preference_child_with_audit(
        @preference_cookie,
        update_params,
        "UPDATE_PREFERENCE_COOKIE",
      )
      reload_preferences_and_reissue_token!
    end
  end

  private

  def load_or_refresh_preference_child(child_type, default_attributes = {})
    association_name = :"#{preference_prefix_underscore}_#{child_type.to_s.underscore}"

    # Access-token loading can leave a child association memoized on @preferences.
    # Reload it here so preference edit/update screens render the latest DB value
    # without forcing the generic loader to refresh associations for every caller.
    if @preferences.persisted?
      association = @preferences.association(association_name)
      association.reload if association.loaded?
    end

    load_or_create_preference_child(child_type, default_attributes)
  end

  def reload_preferences_and_reissue_token!
    @preferences.reload
    # Force reload all preference associations to ensure they reflect DB state
    Preference::ClassRegistry::CHILD_RECORD_TYPES.each do |type|
      assoc_name = "#{preference_prefix_underscore}_#{type}"
      @preferences.association(assoc_name.to_sym).reload if @preferences.respond_to?(assoc_name)
    end
    issue_access_token_from(@preferences)

    sync_to_resource_preference!
  end

  def render_preference_update_response
    render json: { preference: preference_response_payload }, status: :ok
  end

  def preference_response_payload
    snapshot = resolved_preference_snapshot(@preferences)
    cookie = resolved_preference_cookie(@preferences)

    {
      lx: snapshot[:language] || Actor::Preference::DEFAULTS[:language],
      ct: snapshot[:theme] || Actor::Preference::DEFAULTS[:theme],
      ri: snapshot[:region] || Actor::Preference::DEFAULTS[:region],
      tz: snapshot[:timezone] || Actor::Preference::DEFAULTS[:timezone],
      cu: snapshot[:currency] || "jpy",
      df: snapshot[:date_format] || "iso",
      tf: snapshot[:time_format] || "hour_24",
      mo: snapshot[:motion] || "standard",
      dn: snapshot[:density] || "standard",
      ipp: snapshot[:items_per_page] || "20",
      consented: cookie[:consented],
      functional: cookie[:functional],
      performant: cookie[:performant],
      targetable: cookie[:targetable],
    }
  end

  # Dual-write: when logged in, sync current AppPreference/ComPreference/OrgPreference values
  # to the corresponding UserPreference/VisitorPreference/OperatorPreference.
  def sync_to_resource_preference!
    return unless respond_to?(:current_resource, true)

    resource = begin; current_resource; rescue; nil; end
    return if resource.blank?

    resource_pref =
      case preference_class.name
      when "AppPreference" then resource.user_preference
      when "ComPreference" then ensure_visitor_resource_preference_for_sync(resource)
      when "OrgPreference" then resource.staff_preference
      end
    return if resource_pref.blank?

    sync_direct_resource_preference!(resource_pref)
    copy_preference_values!(@preferences, resource_pref, resource_pref_prefix_for_sync)
  rescue StandardError => e
    Rails.event.record("preference.sync_to_resource.error", error: e.class.name, message: e.message)
  end

  def resource_pref_prefix_for_sync
    case preference_class.name
    when "AppPreference" then "User"
    when "ComPreference" then "Visitor"
    when "OrgPreference" then "Operator"
    end
  end

  def sync_direct_resource_preference!(resource_pref)
    snapshot = preference_snapshot_for(@preferences)
    cookie = resolved_preference_cookie(@preferences)
    attrs = snapshot.merge(cookie).compact
    return if attrs.blank?

    resource_pref.update!(attrs)
  end

  def ensure_visitor_resource_preference_for_sync(resource)
    return unless resource.respond_to?(:visitor_preference)

    resource.visitor_preference || build_visitor_resource_preference_for_sync(resource)
  end

  def build_visitor_resource_preference_for_sync(resource)
    preference = resource.create_visitor_preference
    Preference::ClassRegistry::CHILD_RECORD_TYPES.each do |type|
      Preference::ClassRegistry.record_class("Visitor", type).create!(
        preference: preference,
        option_id: Preference::ClassRegistry.default_option_id("Visitor", type),
      )
    end
    preference.reload
  end

  def preference_cookie_params
    return params.fetch(:preference_cookie, {}).permit(
      :functional, :performant, :targetable, :consented, :consented_at,
    ) if params[:preference_cookie]

    params.permit(:functional, :performant, :targetable, :consented, :consented_at)
  end

  def build_cookie_update_params(cookie, params)
    # Ensure nested params are a Hash with indifferent access for reliable key access.
    # Note: Rails 8 `expect` returns an ActionController::Parameters object,
    # which we want to convert to Hash with indifferent access after ensuring it's permitted.
    p_hash = params.to_h.with_indifferent_access
    return p_hash unless p_hash.has_key?(:consented)

    consent_value = ActiveModel::Type::Boolean.new.cast(p_hash[:consented])

    if consent_value && !cookie.consented?
      p_hash[:consented_at] = Time.current
    elsif !consent_value && cookie.consented?
      p_hash[:consented_at] = nil
    end
    p_hash
  end

  def preference_language_params
    params.fetch(:preference_language, {}).permit(:option_id)
  end

  def preference_timezone_params
    params.fetch(:preference_timezone, {}).permit(:option_id)
  end

  def preference_region_params
    params.fetch(:preference_region, {}).permit(:option_id)
  end

  def preference_colortheme_params
    return params.fetch(:preference_colortheme, {}).permit(:option_id) if params[:preference_colortheme]
    return params.fetch(:preference_theme, {}).permit(:option_id) if params[:preference_theme]

    ActionController::Parameters.new(
      option_id: params[:option_id] || params[:theme] || params[:ct],
    ).permit(:option_id)
  end

  def selectable_preference_params(type)
    param_scope = :"preference_#{type}"
    return params.fetch(param_scope, {}).permit(:option_id) if params[param_scope]

    ActionController::Parameters.new(
      option_id: params[:option_id] || params[type],
    ).permit(:option_id)
  end

  def preference_child_class_suffix(type)
    {
      currency: "Currency",
      date_format: "DateFormat",
      time_format: "TimeFormat",
      motion: "Motion",
      density: "Density",
      items_per_page: "ItemsPerPage",
    }.fetch(type.to_sym)
  end

  def load_or_build_selectable_preference_child(type)
    type = type.to_sym
    association_name = :"#{preference_prefix_underscore}_#{type}"
    child = @preferences.public_send(association_name)
    return child if child.present?

    Preference::ClassRegistry.record_class(preference_prefix, type).new(
      preference: @preferences,
      option_id: Preference::ClassRegistry.default_option_id(preference_prefix, type),
    )
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

  def safe_return_to_path
    return if params[:return_to].blank?

    candidate = params.expect(:return_to).to_s
    return unless candidate.start_with?("/")
    return if candidate.start_with?("//")

    candidate
  end

  def preference_edit_url(screen, params_hash = {})
    public_send(preference_edit_url_helper_name(screen), params_hash)
  end

  def preference_update_url(screen, params_hash = {})
    public_send(preference_url_helper_name(screen), params_hash)
  end

  def preference_index_url(params_hash = {})
    public_send("sign_#{preference_surface_key}_preference_url", params_hash)
  end

  def preference_update_notice
    t("#{preference_translation_scope}.update_success")
  end

  def preference_reset_destroyed_notice
    t("apex.#{preference_surface_key}.preference.resets.destroyed")
  end

  def preference_operation_failed_alert
    I18n.t("errors.messages.preference_operation_failed")
  end

  def preference_context_redirect_params
    Preference::Global::PARAM_CONTEXT_KEYS.each_with_object({}) do |key, memo|
      memo[key] = params[key] if params[key].present?
    end
  end

  def language_preference_redirect_params
    return {} if params[:lx].blank? || @preference_language&.option_id.blank?

    { lx: option_id_to_language(@preference_language.option_id, preference_prefix) }
  end

  def apply_language_preference_to_session
    return if @preference_language&.option_id.blank?

    session[:language] = option_id_to_language(@preference_language.option_id, preference_prefix)
  end

  def updated_region_redirect_params
    return {} if @preference_region&.option_id.blank?

    { ri: option_id_to_region(@preference_region.option_id, preference_prefix) }
  end

  def delete_preference_cookie
    preference = find_preference_for_delete
    if preference.present?
      log_preference_reset(preference)
      # Keep cookies and records intact on logout; do not delete or reset preference values.
      # The preference record and cookies remain so the user retains their settings.
    end
    reset_preference_state
    nil
  end

  # Reset preferences to defaults (explicit user action, not logout).
  # Resets BOTH AppPreference/OrgPreference AND UserPreference/OperatorPreference.
  def reset_preference_to_defaults!
    return if @preferences.blank?

    reset_app_org_preference_to_defaults!(@preferences)
    reset_resource_preference_to_defaults!

    create_audit_log(
      event_id: preference_audit_event_class::RESET_BY_USER_DECISION,
      context: { preference_reset: true, reset_to_defaults: true },
    )

    reload_preferences_and_reissue_token!
  end

  private

  def find_preference_for_delete
    return @preferences if @preferences.present?

    token_value = refresh_token_value
    @refresh_token_value = token_value
    return nil if token_value.blank?

    token_digest = refresh_token_lookup_digest(token_value)
    return nil unless token_digest

    with_preference_connection(:writing) do
      preference_class.find_by(token_digest: token_digest)
    end
  end

  def log_preference_reset(preference)
    @preferences = preference
    create_audit_log(
      event_id: preference_audit_event_class::RESET_BY_USER_DECISION,
      context: { preference_reset: true, kept_values: true },
    )
  rescue StandardError => e
    Rails.logger.error("log_preference_reset failed: #{e.class} - #{e.message}")
  end

  def reset_app_org_preference_to_defaults!(preference)
    association_prefix = preference.class.name.underscore
    prefix = preference_prefix

    with_preference_connection(:writing) do
      Preference::Adoption::CHILD_RECORD_TYPES.each do |type|
        child = preference.public_send("#{association_prefix}_#{type}")
        next unless child

        ensure_model_defaults!(Preference::ClassRegistry.option_class(prefix, type))
        default_id = Preference::ClassRegistry.default_option_id(prefix, type)
        child.update!(option_id: default_id) if child.option_id != default_id
      end

      cookie = preference.public_send("#{association_prefix}_cookie")
      cookie&.update!(
        consented: false,
        functional: false,
        performant: false,
        targetable: false,
        consented_at: nil,
      )
    end
  end

  def reset_resource_preference_to_defaults!
    return unless respond_to?(:current_resource, true)

    resource = begin; current_resource; rescue; nil; end
    return if resource.blank?

    resource_pref =
      case preference_class.name
      when "AppPreference" then resource.user_preference
      when "ComPreference" then ensure_visitor_resource_preference_for_sync(resource)
      when "OrgPreference" then resource.staff_preference
      end
    return if resource_pref.blank?

    res_prefix = resource_pref_prefix_for_sync
    resource_assoc = resource_pref.class.name.underscore
    connection_class =
      resource_pref.class.ancestors.find { |ancestor| ancestor.is_a?(Class) && ancestor < ActiveRecord::Base && ancestor.abstract_class? }

    connection_class.connected_to(role: :writing) do
      Preference::Adoption::CHILD_RECORD_TYPES.each do |type|
        child = resource_pref.public_send("#{resource_assoc}_#{type}")
        next unless child

        ensure_model_defaults!(Preference::ClassRegistry.option_class(res_prefix, type))
        default_id = Preference::ClassRegistry.default_option_id(res_prefix, type)
        child.update!(option_id: default_id) if child.option_id != default_id
      end

      # Reset cookie consent columns
      resource_pref.update!(
        consented: false, functional: false,
        performant: false, targetable: false,
        consented_at: nil,
      )
    end
  rescue StandardError => e
    Rails.event.record("preference.reset_resource.error", error: e.class.name, message: e.message)
  end

  def reset_preference_state
    @preferences = nil
    @preference_payload = nil
    @refresh_token_value = nil
  end

  def preference_surface_key
    preference_class.name.delete_suffix("Preference").downcase
  end

  def preference_translation_scope
    "apex.#{preference_surface_key}.preferences"
  end

  def preference_edit_url_helper_name(screen)
    "edit_#{preference_url_helper_name(screen)}"
  end

  def preference_url_helper_name(screen)
    suffix =
      case screen
      when :region then "region"
      when :language then "region_language"
      when :timezone then "region_timezone"
      when :currency then "region_currency"
      when :date_format then "region_date_format"
      when :time_format then "region_time_format"
      when :motion then "accessibility_motion"
      when :density then "display_density"
      when :items_per_page then "display_items_per_page"
      when :theme then "theme"
      when :cookie then "cookie"
      when :reset then "reset"
      else
        raise ArgumentError, "Unknown preference screen: #{screen.inspect}"
      end

    "sign_#{preference_surface_key}_preference_#{suffix}_url"
  end

  def preference_group_screen(screen)
    case screen.to_sym
    when :currency, :date_format, :time_format then :region
    end
  end

  def preference_option_label(type, value)
    key = "apex.#{preference_surface_key}.preference.#{type}.options.#{value}"
    default = value.to_s.tr("_", " ").titleize
    I18n.t(key, default: default)
  end
end
