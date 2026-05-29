# typed: false
# frozen_string_literal: true

module Preference::Core
  extend ActiveSupport::Concern
  include Common::Redirect
  include Preference::Base
  include Preference::ResourceSync

  COOKIE_EXPIRY = 400.days

  def set_region_preferences_edit
    with_preference_connection(:writing) do
      @preference_region = load_or_refresh_preference_child("Region", option_id: nil)
    end
  end

  def set_region_preferences_update
    with_preference_connection(:writing) do
      @preference_region = load_or_refresh_preference_child("Region", option_id: nil)

      update_preference_child_with_resource_first!(
        @preference_region,
        sanitize_option_id(preference_region_params, option_type: :region),
        option_type: :region,
        audit_event: "UPDATE_PREFERENCE_REGION",
      )
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

      update_preference_child_with_resource_first!(
        @preference_language,
        sanitize_option_id(preference_language_params, option_type: :language),
        option_type: :language,
        audit_event: "UPDATE_PREFERENCE_LANGUAGE",
      )
    end

    return if @preference_language.option_id.blank?

    language = option_id_to_language(@preference_language.option_id, preference_prefix)
    write_preference_cookie(Preference::Base::LANGUAGE_COOKIE_KEY, language) if language.present?
  end

  def set_timezone_preferences_edit
    with_preference_connection(:writing) do
      ensure_model_defaults!(Preference::ClassRegistry.option_class(preference_prefix, :timezone))
      @preference_timezone = load_or_refresh_preference_child("Timezone", option_id: nil)
    end

    timezone = option_id_to_timezone(@preference_timezone.option_id, preference_prefix)
    Time.zone = timezone if timezone.present?
  end

  def set_timezone_preferences_update
    @preferences ||= ensure_preferences_record
    raise PreferenceOperationError if @preferences.blank?

    submitted_timezone = preference_timezone_params[Preference::IoKeys::Params::OPTION_ID]

    with_preference_connection(:writing) do
      ensure_model_defaults!(Preference::ClassRegistry.option_class(preference_prefix, :timezone))
      @preference_timezone = load_or_refresh_preference_child("Timezone", option_id: nil)

      begin
        update_preference_child_with_resource_first!(
          @preference_timezone,
          sanitize_option_id(preference_timezone_params, option_type: :timezone),
          option_type: :timezone,
          audit_event: "UPDATE_PREFERENCE_TIMEZONE",
        )
      rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ArgumentError
        raise PreferenceOperationError
      end
    end

    return if @preference_timezone.option_id.blank?

    @preference_timezone.reload
    timezone = resolved_writable_timezone(@preference_timezone, submitted_timezone)
    return if timezone.blank?

    Time.zone = timezone
    session[:timezone] = timezone
    write_preference_cookie(Preference::Base::TIMEZONE_COOKIE_KEY, timezone)
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

      update_preference_child_with_resource_first!(
        @preference_colortheme,
        sanitize_option_id(preference_colortheme_params, option_type: :colortheme),
        option_type: :theme,
        audit_event: "UPDATE_PREFERENCE_COLORTHEME",
      )
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

      update_preference_child_with_resource_first!(
        @preference_option,
        sanitize_option_id(selectable_preference_params(type), option_type: type),
        option_type: type,
        audit_event: "UPDATE_PREFERENCE_#{type.to_s.upcase}",
      )
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

      update_preference_cookie_with_resource_first!(
        @preference_cookie,
        update_params,
        audit_event: "UPDATE_PREFERENCE_COOKIE",
      )
    end
  end

  private

  # Resolves the timezone that may be persisted to Time.zone / session / cookie.
  # Only IANA names accepted by ActiveSupport::TimeZone may flow through; any
  # raw submitted string must pass this allowlist before being trusted.
  def resolved_writable_timezone(preference_record, submitted_value)
    submitted = normalize_known_timezone(submitted_value)
    return submitted if submitted.present?

    normalize_known_timezone(option_id_to_timezone(preference_record.option_id, preference_prefix))
  end

  def normalize_known_timezone(value)
    candidate = value.to_s.strip
    return nil if candidate.blank?

    zone = ActiveSupport::TimeZone[candidate]
    return nil if zone.nil?

    zone.tzinfo&.name || zone.name
  end

  def load_or_refresh_preference_child(child_type, default_attributes = {})
    association_name = :"#{preference_prefix_underscore}_#{child_type.to_s.underscore}"
    @preferences ||= ensure_preferences_record

    # Access-token loading can leave a child association memoized on @preferences.
    # Reload it here so preference edit/update screens render the latest DB value
    # without forcing the generic loader to refresh associations for every caller.
    if @preferences.persisted?
      association = @preferences.association(association_name)
      association.reload if association.loaded?
    end

    load_or_create_preference_child(child_type, default_attributes)
  end

  def reload_preferences_and_reissue_token!(sync_resource: true)
    @preferences.reload
    # Force reload all preference associations to ensure they reflect DB state
    Preference::ClassRegistry::CHILD_RECORD_TYPES.each do |type|
      assoc_name = "#{preference_prefix_underscore}_#{type}"
      @preferences.association(assoc_name.to_sym).reload if @preferences.respond_to?(assoc_name)
    end
    issue_access_token_from(@preferences)

    sync_to_resource_preference! if sync_resource
  end

  def update_preference_child_with_resource_first!(child, attributes, option_type:, audit_event:)
    raise PreferenceOperationError if child.blank? || attributes.blank?

    p_hash = attributes.to_h.with_indifferent_access
    resource_pref = preference_write_resource_preference!
    authorize_resource_preference_write!(resource_pref)
    write_resource_preference_option!(
      resource_pref, option_type,
      p_hash[Preference::IoKeys::Params::OPTION_ID],
    ) if resource_pref

    update_preference_child_with_audit(child, p_hash, audit_event)
    reload_preferences_and_reissue_token!(sync_resource: false)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ActionPolicy::Unauthorized, ArgumentError => e
    record_preference_write_error("preference.write.option_error", e, target: option_type)
    raise PreferenceOperationError
  end

  def update_preference_cookie_with_resource_first!(cookie, attributes, audit_event:)
    raise PreferenceOperationError if cookie.blank? || attributes.blank?

    p_hash = attributes.to_h.with_indifferent_access
    resource_pref = preference_write_resource_preference!
    authorize_resource_preference_write!(resource_pref)
    write_resource_preference_cookie!(resource_pref, p_hash) if resource_pref

    update_preference_child_with_audit(cookie, p_hash, audit_event)
    reload_preferences_and_reissue_token!(sync_resource: false)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey, ActionPolicy::Unauthorized, ArgumentError => e
    record_preference_write_error("preference.write.cookie_error", e, target: :cookie)
    raise PreferenceOperationError
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

  def record_preference_write_error(event_name, error, target:)
    Rails.logger.info(
      Jit::LogEvent.format(
        event_name,
        error: error.class.name,
        message: error.message,
        preference_type: preference_class.name,
        target: target.to_s,
        surface: preference_surface_key,
        owner_id: preference_write_owner_id,
        request_id: request.request_id,
      ),
    )
  end

  def preference_write_owner_id
    resource = preference_current_resource
    resource&.id
  end

  # Resolves the post-update redirect target carried by params[:pt].
  # Delegates path validation to Common::Redirect so the same rules
  # (no scheme, no host, no protocol-relative '//', no encoded backslash)
  # apply consistently across the app.
  def safe_pt_path
    raw = params["pt"]
    return if raw.blank?

    safe_internal_path(raw.to_s)
  end

  def preference_edit_url(screen, params_hash = {})
    public_send(preference_edit_url_helper_name(screen), compact_url_params(params_hash))
  end

  def preference_update_url(screen, params_hash = {})
    public_send(preference_url_helper_name(screen), compact_url_params(params_hash))
  end

  def preference_index_url(params_hash = {})
    public_send("sign_#{preference_surface_key}_preference_url", compact_url_params(params_hash))
  end

  def preference_update_notice
    t([preference_translation_scope, "update_success"].join("."))
  end

  def preference_reset_destroyed_notice
    t(["acme", preference_surface_key, "preference.resets.destroyed"].join("."))
  end

  def preference_operation_failed_alert
    I18n.t("errors.messages.preference_operation_failed")
  end

  def preference_context_redirect_params
    Preference::Global::PARAM_CONTEXT_KEYS.each_with_object({}) do |key, memo|
      memo[key] = params[key] if params[key].present?
    end
  end

  def preference_write_redirect_params(except: nil)
    except_keys = Array(except).compact.map(&:to_sym)
    preference_context_redirect_params.except(*except_keys).tap do |redirect_params|
      except_keys.each { |key| redirect_params[key] = nil }
      redirect_params[:ri] = params[:ri].presence || get_region
    end
  end

  def language_preference_redirect_params
    preference_write_redirect_params(except: :lx)
  end

  def apply_language_preference_to_session
    return if @preference_language&.option_id.blank?

    session[:language] = option_id_to_language(@preference_language.option_id, preference_prefix)
  end

  def updated_region_redirect_params
    return {} if @preference_region&.option_id.blank?

    preference_context_redirect_params.merge(
      ri: option_id_to_region(@preference_region.option_id, preference_prefix),
    )
  end

  def compact_url_params(params_hash)
    params_hash.to_h
  end

  def preference_context_key_for_screen(screen)
    {
      currency: :cu,
      date_format: :df,
      time_format: :tf,
      motion: :mo,
      density: :dn,
      items_per_page: :pp,
    }[screen.to_sym]
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
  # Resets BOTH AppPreference/OrgPreference AND ClientPreference/OperatorPreference.
  def reset_preference_to_defaults!
    return if @preferences.blank?

    reset_resource_preference_to_defaults!
    reset_app_org_preference_to_defaults!(@preferences)

    create_audit_log(
      event_id: preference_audit_event_class::RESET_BY_USER_DECISION,
      context: { preference_reset: true, reset_to_defaults: true },
    )

    reload_preferences_and_reissue_token!(sync_resource: false)
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
    resource_pref = preference_write_resource_preference!
    return if resource_pref.blank?

    authorize_resource_preference_write!(resource_pref)
    reset_resource_preference_defaults_for_write!(resource_pref)
  rescue StandardError => e
    record_preference_write_error("preference.reset_resource.error", e, target: :reset)
    raise PreferenceOperationError
  end

  def reset_preference_state
    @preferences = nil
    @preference_payload = nil
    @refresh_token_value = nil
  end

  def safe_return_to_path
    safe_return_path(params[:return_to])
  end

  def preference_surface_key
    preference_class.name.delete_suffix("Preference").downcase
  end

  def preference_translation_scope
    "acme.#{preference_surface_key}.preferences"
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
      when :date_format then "region_date"
      when :time_format then "region_time"
      when :motion then "accessibility_motion"
      when :density then "accessibility_density"
      when :items_per_page then "display_items_per_page"
      when :r18_display_stopper then "display_r18_display_stopper"
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
    key = "acme.#{preference_surface_key}.preference.#{type}.options.#{value}"
    default = value.to_s.tr("_", " ").titleize
    I18n.t(key, default: default)
  end
end
