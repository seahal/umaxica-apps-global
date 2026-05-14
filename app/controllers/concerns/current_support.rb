# typed: false
# frozen_string_literal: true

module CurrentSupport
  extend ActiveSupport::Concern

  included do
    after_action :_reset_current_state
  end

  private

  def set_current
    context = resolved_current_context
    Actor.surface = context.surface
    Actor.domain = context.surface
    Actor.account = context.account
    Actor.tenant = context.tenant

    resource = safe_current_resource
    actor = resource.presence || Unauthenticated.instance
    actor_type = resolved_current_actor_type(resource)
    Actor.actor = actor
    Actor.actor_type = actor_type
    Actor.session ||= resolved_current_session
    Actor.token ||= resolved_current_token
    Actor.preference = resolved_current_preference(resource)
  end

  def _reset_current_state
    Actor.reset
  end

  def resolved_current_context
    if Actor.surface.present?
      return HostContextResolver::Context.new(
        surface: Actor.surface,
        account: Actor.account,
        tenant: Actor.tenant,
      )
    end
    if Actor.domain.present?
      return HostContextResolver::Context.new(
        surface: Actor.domain,
        account: Actor.account,
        tenant: Actor.tenant,
      )
    end
    unless respond_to?(:request, true) && request.present?
      return HostContextResolver::Context.new(
        surface: nil,
        account: Actor.account,
        tenant: Actor.tenant,
      )
    end

    HostContextResolver.call(request)
  end

  def resolved_current_domain
    resolved_current_context.surface
  end

  def safe_current_resource
    current_actor = Actor.actor
    if current_actor.present?
      return current_actor unless current_actor.equal?(Unauthenticated.instance)
    end
    return unless respond_to?(:current_resource, true)

    current_resource
  rescue StandardError
    nil
  end

  def resolved_current_actor_type(resource)
    actor_type = Actor.attributes[:actor_type]
    return actor_type if actor_type.present? && actor_type != :unauthenticated
    return :unauthenticated if resource.blank?

    if resource.respond_to?(:operator?) && resource.operator?
      :operator
    elsif resource.respond_to?(:visitor?) && resource.visitor?
      :visitor
    else
      :user
    end
  end

  def resolved_current_session
    return Actor.session if Actor.session.present?
    return @current_session_public_id if defined?(@current_session_public_id) && @current_session_public_id.present?

    resolved_current_token&.dig("sid")
  end

  def resolved_current_token
    return Actor.token if Actor.token.present?

    payload = nil
    payload = access_token_payload if respond_to?(:access_token_payload, true)
    payload ||= load_access_token_payload if respond_to?(:load_access_token_payload, true)
    payload if payload.is_a?(Hash)
  rescue StandardError
    nil
  end

  def resolved_current_preference(resource)
    cookie = resolved_current_cookie(resource)

    preference_record = resolved_resource_preference(resource)
    return preference_from_record(preference_record, cookie: cookie) if preference_record.present?

    prf_claim = resolved_current_token&.dig("prf")
    return Actor::Preference.from_jwt(prf_claim, cookie: cookie) if prf_claim.is_a?(Hash)

    Actor::Preference::NULL.with_cookie(cookie)
  end

  def resolved_current_cookie(resource)
    preference_record = resolved_resource_preference(resource)
    if preference_record.present?
      return Actor::Preference.cookie_from(
        consented: preference_record.consented,
        functional: preference_record.functional,
        performant: preference_record.performant,
        targetable: preference_record.targetable,
        consent_version: preference_record.try(:consent_version),
        consented_at: preference_record.consented_at,
      )
    end

    if respond_to?(:preference_payload_preferences, true)
      payload_preferences = preference_payload_preferences
      if payload_preferences.is_a?(Hash)
        return Actor::Preference.cookie_from(
          consented: payload_preferences["consented"],
          functional: payload_preferences["functional"],
          performant: payload_preferences["performant"],
          targetable: payload_preferences["targetable"],
          consent_version: payload_preferences["consent_version"],
          consented_at: payload_preferences["consented_at"],
        )
      end
    end

    Actor::Preference::NULL_COOKIE
  end

  def resolved_resource_preference(resource)
    return if resource.blank?

    if resource.respond_to?(:operator?) && resource.operator?
      resource.try(:staff_preference)
    elsif resource.respond_to?(:visitor?) && resource.visitor?
      resource.try(:visitor_preference)
    else
      resource.try(:user_preference)
    end
  end

  def preference_from_record(preference_record, cookie:)
    Actor::Preference.new(
      language: preference_record.language.presence || Actor::Preference::DEFAULTS[:language],
      region: preference_record.region.presence || Actor::Preference::DEFAULTS[:region],
      timezone: preference_record.timezone.presence || Actor::Preference::DEFAULTS[:timezone],
      theme: preference_record.theme.presence || Actor::Preference::DEFAULTS[:theme],
      cookie: cookie,
      public_id: preference_record.try(:public_id),
    )
  end

  def set_current_observability
    return unless defined?(OpenTelemetry::Trace)
    return unless Actor.preference.cookie.performant?

    span = OpenTelemetry::Trace.current_span
    context = span.context
    return unless context.valid?

    Actor.trace_id = context.hex_trace_id
    Actor.span_id = context.hex_span_id
  end
end
