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
    association_name = :"#{preference_prefix_underscore}_#{child_type.downcase}"

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
    %w(language region timezone colortheme).each do |type|
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
      lx: snapshot[:language] || Current::Preference::DEFAULTS[:language],
      ct: snapshot[:theme] || Current::Preference::DEFAULTS[:theme],
      ri: snapshot[:region] || Current::Preference::DEFAULTS[:region],
      tz: snapshot[:timezone] || Current::Preference::DEFAULTS[:timezone],
      consented: cookie[:consented],
      functional: cookie[:functional],
      performant: cookie[:performant],
      targetable: cookie[:targetable],
    }
  end

  # Dual-write: when logged in, sync current AppPreference/ComPreference/OrgPreference values
  # to the corresponding UserPreference/CustomerPreference/StaffPreference.
  def sync_to_resource_preference!
    return unless respond_to?(:current_resource, true)

    resource = begin; current_resource; rescue; nil; end
    return if resource.blank?

    resource_pref =
      case preference_class.name
      when "AppPreference" then resource.user_preference
      when "ComPreference" then ensure_customer_resource_preference_for_sync(resource)
      when "OrgPreference" then resource.staff_preference
      end
    return if resource_pref.blank?

    copy_preference_values!(@preferences, resource_pref, resource_pref_prefix_for_sync)
  rescue StandardError => e
    Rails.event.record("preference.sync_to_resource.error", error: e.class.name, message: e.message)
  end

  def resource_pref_prefix_for_sync
    case preference_class.name
    when "AppPreference" then "User"
    when "ComPreference" then "Customer"
    when "OrgPreference" then "Staff"
    end
  end

  def ensure_customer_resource_preference_for_sync(resource)
    return unless resource.respond_to?(:customer_preference)

    resource.customer_preference || build_customer_resource_preference_for_sync(resource)
  end

  def build_customer_resource_preference_for_sync(resource)
    preference = resource.create_customer_preference
    CustomerPreferenceLanguage.create(preference: preference)
    CustomerPreferenceTimezone.create(preference: preference)
    CustomerPreferenceRegion.create(preference: preference)
    CustomerPreferenceColortheme.create(preference: preference)
    preference.reload
  end

  def preference_cookie_params
    return params.expect(
      preference_cookie: %i(functional performant targetable consented
                            consented_at),
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
    params.expect(preference_language: [:option_id])
  end

  def preference_timezone_params
    params.expect(preference_timezone: [:option_id])
  end

  def preference_region_params
    params.expect(preference_region: [:option_id])
  end

  def preference_colortheme_params
    return params.expect(preference_colortheme: [:option_id]) if params[:preference_colortheme]

    ActionController::Parameters.new(
      option_id: params[:option_id] || params[:theme] || params[:ct],
    ).permit(:option_id)
  end

  def resolved_preference_snapshot(preference)
    return {} if preference.blank?

    if preference.respond_to?(:language) &&
        preference.respond_to?(:region) &&
        preference.respond_to?(:timezone) &&
        preference.respond_to?(:theme)
      return {
        language: preference.language,
        region: preference.region,
        timezone: preference.timezone,
        theme: preference.theme,
      }.compact
    end

    association_prefix = preference.class.name.underscore

    {
      language: preference.public_send("#{association_prefix}_language")&.option&.name&.downcase,
      region: preference.public_send("#{association_prefix}_region")&.option&.name&.downcase,
      timezone: preference.public_send("#{association_prefix}_timezone")&.option&.name,
      theme: colortheme_short_code(preference.public_send("#{association_prefix}_colortheme")&.option&.name),
    }.compact
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

    candidate = params[:return_to].to_s
    return unless candidate.start_with?("/")
    return if candidate.start_with?("//")

    candidate
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
  # Resets BOTH AppPreference/OrgPreference AND UserPreference/StaffPreference.
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

        option_classes = preference_option_classes(prefix)
        default_id =
          case type
          when :timezone then option_classes[:timezone]::ASIA_TOKYO
          when :language then option_classes[:language]::JA
          when :region then option_classes[:region]::JP
          when :colortheme then option_classes[:colortheme]::SYSTEM
          end
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
      when "OrgPreference" then resource.staff_preference
      end
    return if resource_pref.blank?

    res_prefix = resource_pref_prefix_for_sync
    resource_assoc = resource_pref.class.name.underscore

    PrincipalRecord.connected_to(role: :writing) do
      Preference::Adoption::CHILD_RECORD_TYPES.each do |type|
        child = resource_pref.public_send("#{resource_assoc}_#{type}")
        next unless child

        option_classes = preference_option_classes(res_prefix)
        default_id =
          case type
          when :timezone then option_classes[:timezone]::ASIA_TOKYO
          when :language then option_classes[:language]::JA
          when :region then option_classes[:region]::JP
          when :colortheme then option_classes[:colortheme]::SYSTEM
          end
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
end
