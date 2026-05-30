# typed: false
# frozen_string_literal: true

module Preference::Global
  extend ActiveSupport::Concern
  include Preference::Base
  include Preference::Localization

  PUBLIC_CONTEXT_KEYS = RequestContext::Contract.public_keys
  PARAM_CONTEXT_KEYS = (RequestContext::Contract.required_keys + RequestContext::Contract.optional_overlay_keys).freeze
  OPTIONAL_PARAM_KEYS = RequestContext::Contract.optional_overlay_keys
  ALLOWED_REGION_VALUES = RequestContext::Contract.allowed_regions

  DEFAULT_CONTEXT =
    Preference::Constants::DEFAULT_PREFERENCES
      .transform_keys(&:to_sym)
      .transform_values { |value| value.to_s.downcase }
      .freeze

  def resolve_param_context
    effective_context
  end

  def ensure_required_ri!
    return if performed?

    normalized_current = normalized_param_ri
    desired = required_ri
    return if desired.blank? || desired == normalized_current

    redirect_to(
      build_ri_redirect_url(desired),
      allow_other_host: false,
      status: redirect_status_for_ri?,
    )
  end

  def default_context
    DEFAULT_CONTEXT
  end

  def requested_context
    request_context.slice(*PARAM_CONTEXT_KEYS)
  end

  def request_context
    PUBLIC_CONTEXT_KEYS.each_with_object({}) do |key, memo|
      value = request_context_value(key)
      memo[key] = value if value.present?
    end
  end

  def cookie_context
    preferences = preference_payload_preferences
    context = {}
    context.merge!(preference_context_from_hash(preferences)) if preferences.present?
    context.merge!(preference_context_from_record) if @preferences.present?
    context.compact
  end

  def effective_context
    default_context.merge(cookie_context).merge(requested_context)
  end

  def required_ri
    effective_context[:ri]
  end

  def default_url_options
    base_options = super || {}
    context = requested_context.slice(*PARAM_CONTEXT_KEYS)
    context.present? ? base_options.merge(context) : base_options
  end

  def preference_context_from_hash(preferences)
    {
      ri: normalized_preference_value(preferences, "ri"),
      lx: normalized_preference_value(preferences, "lx"),
      tz: preferences["tz"],
      ct: theme_short_code(preferences["ct"]),
    }
  end

  def preference_context_from_record
    prefix = preference_prefix(@preferences)

    {
      ri: option_id_to_region(preference_option_id(association_name_for_region), prefix),
      lx: option_id_to_language(preference_option_id(association_name_for_language), prefix),
      tz: option_id_to_timezone(preference_option_id(association_name_for_timezone), prefix),
      ct: theme_short_code(preference_option_value(preference_theme_association)),
    }
  end

  def normalized_preference_value(preferences, key)
    preferences[key]&.to_s&.downcase
  end

  private

  def preference_option_value(association_name)
    option_id = preference_option_id(association_name)
    option_id&.to_s&.downcase
  end

  def preference_option_id(association_name)
    return nil if @preferences.blank? || association_name.blank?

    record = @preferences.public_send(association_name)
    record&.option_id
  rescue NoMethodError
    nil
  end

  def association_name_for_region
    :"#{preference_prefix_underscore}_region"
  rescue NoMethodError
    nil
  end

  def association_name_for_language
    :"#{preference_prefix_underscore}_language"
  rescue NoMethodError
    nil
  end

  def association_name_for_timezone
    :"#{preference_prefix_underscore}_timezone"
  rescue NoMethodError
    nil
  end

  def normalized_param_ri
    request_context_ri
  end

  def request_context_value(key)
    key = key.to_sym
    return unless PUBLIC_CONTEXT_KEYS.include?(key)

    raw_value = params[key].presence
    return if raw_value.blank?

    normalized_value = RequestContext::Contract.normalize(key, raw_value)
    return unless valid_requested_context_value?(key, normalized_value)

    normalized_value
  end

  PUBLIC_CONTEXT_KEYS.each do |key|
    define_method(:"request_context_#{key}") do
      request_context_value(key)
    end
  end

  def valid_ri_value?(value)
    value.present? && allowed_region_values.include?(value)
  end

  def valid_requested_context_value?(key, value)
    case key
    when :ri
      valid_ri_value?(value)
    when :lx
      normalized_locale(value).present?
    when :ct
      normalize_theme(value).present?
    when :tz
      valid_timezone_value?(value)
    else
      true
    end
  end

  def valid_timezone_value?(value)
    return false if value.blank?

    allowed_requested_timezone_values.include?(value.to_s.downcase)
  end

  def allowed_requested_timezone_values
    %w(
      utc
      etc/utc
      jst
      asia/tokyo
      america/new_york
      america/chicago
      america/denver
      america/los_angeles
      america/anchorage
      pacific/honolulu
    ).freeze
  end

  def allowed_region_values
    return ALLOWED_REGION_VALUES if @preferences.blank?

    @allowed_region_values ||=
      begin
        region_option_class = Preference::ClassRegistry.option_class(preference_prefix, :region)
        values = region_option_class.filter_map { |option| option.name&.downcase }.presence
        values || ALLOWED_REGION_VALUES
      rescue KeyError, NameError
        ALLOWED_REGION_VALUES
      end
  end

  def build_ri_redirect_url(ri_value)
    query = request.query_parameters.merge("ri" => ri_value)
    base = "#{request.base_url}#{request.path}"
    query_string = query.to_query
    query_string.blank? ? base : "#{base}?#{query_string}"
  end

  def redirect_status_for_ri?
    (request.get? || request.head?) ? :found : :see_other
  end

  def get_theme
    "sy"
  end

  def get_language
    I18n.locale.to_s
  end

  def get_region
    required_ri.presence || "jp"
  end

  def get_timezone
    "ASIA/Tokyo"
  end

  def set_region
    return if request_format_json?

    normalized_ri = normalized_param_ri
    redirect_params = sanitized_context_query_parameters
    query_changed = redirect_params != request.query_parameters

    if valid_ri_value?(normalized_ri)
      return unless query_changed && (request.get? || request.head?)

      return redirect_to_context_query(redirect_params)
    end

    return unless request.get? || request.head? || params[:ri].present?

    redirect_params = redirect_params.merge("ri" => get_region)
    redirect_to_context_query(redirect_params)
  end

  def sanitized_context_query_parameters
    request.query_parameters.dup.tap do |query|
      query.delete("lx") if query.key?("lx") && !valid_requested_context_value?(:lx, query["lx"])
      query.delete("ct") if query.key?("ct") && !valid_requested_context_value?(:ct, query["ct"])
      query.delete("tz") if query.key?("tz") && !valid_requested_context_value?(:tz, query["tz"])
    end
  end

  def redirect_to_context_query(redirect_params)
    redirect_url = url_for(
      protocol: request.protocol,
      host: request.host,
      port: request.port,
      controller: controller_path,
      action: action_name,
      **redirect_params.symbolize_keys,
      only_path: false,
    )

    redirect_to(redirect_url, status: redirect_status_for_ri?)
  end

  def request_format_json?
    request.respond_to?(:format) && request.format.json?
  end

  def set_locale
    I18n.locale = Actor.preferences.locale if defined?(Actor)
    write_preference_cookie(Preference::Base::LANGUAGE_COOKIE_KEY, I18n.locale.to_s.downcase)
  end

  def set_timezone
    timezone = effective_context[:tz]
    timezone = Actor.preferences.timezone if timezone.blank? && defined?(Actor)
    timezone_value = normalize_timezone_value(timezone.presence || Time.zone&.name)
    Time.zone = timezone_value if timezone_value.present?
    session[:timezone] = timezone_value if timezone_value.present?
    write_preference_cookie(Preference::Base::TIMEZONE_COOKIE_KEY, timezone_value) if timezone_value.present?
  end

  def normalize_timezone_value(value)
    case value.to_s.downcase
    when "jst"
      "Asia/Tokyo"
    when "utc", "etc/utc"
      "Etc/UTC"
    else
      value.presence
    end
  end
end
