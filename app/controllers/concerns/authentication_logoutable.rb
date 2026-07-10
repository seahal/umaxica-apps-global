# typed: false
# frozen_string_literal: true

# Ordinary "sign out" flow. Revokes only the **current** session token,
# clears auth cookies, and resets the Rails session.
#
# "Sign out from all devices" must be invoked explicitly via
# `logout_all_sessions_for!` from a dedicated endpoint (settings UI,
# password rotation, lifecycle transition, etc.). Do NOT call it from this
# path: a user clicking "Sign out" expects only the current browser to be
# signed out.
#
# Note: `Oidc::SingleLogoutService` is intentionally NOT invoked here. Its
# current implementation revokes every active token for the actor and is
# closer to an admin-side "revoke all sessions" routine than an OIDC SLO
# protocol notifier. Re-introducing it on this path would silently downgrade
# ordinary logout to a global logout (which was the bug fixed in this file).
module AuthenticationLogoutable
  extend ActiveSupport::Concern

  class ResolutionError < StandardError; end

  private

  def logout_current_session!(reason: "user_logout")
    begin
      resource = safe_current_resource_for_logout
      AuthenticationLogoutCurrentSession.call(
        current: Actor,
        resource: resource,
        token: safe_current_session_for_logout,
        token_class: safe_token_class_for_logout,
        session_public_id: safe_current_session_public_id_for_logout,
        reason: reason,
      )
      record_logout_audit(resource)
    ensure
      clear_auth_cookies! if respond_to?(:clear_auth_cookies!, true)
      Actor.clear if defined?(Actor)
      reset_session
    end
    LogoutResult.success
  end

  # Explicit "sign out from all devices". Callers must be dedicated
  # endpoints (settings UI, admin tools, lifecycle hooks) -- never the
  # ordinary "Sign out" button.
  def logout_all_sessions_for!(resource:, reason:)
    begin
      AuthenticationLogoutAllSessions.call(resource: resource, reason: reason)
      record_logout_all_sessions_audit(resource)
    ensure
      clear_auth_cookies! if respond_to?(:clear_auth_cookies!, true)
      Actor.clear if defined?(Actor)
      reset_session
    end
    LogoutResult.success
  end

  def safe_current_resource_for_logout
    current_resource if respond_to?(:current_resource, true)
  rescue StandardError => e
    raise_logout_resolution_error!(:current_resource, e)
  end

  def safe_current_session_for_logout
    current_session || session_token_from_refresh_cookie_for_logout
  rescue StandardError => e
    raise_logout_resolution_error!(:current_session, e)
  end

  def safe_token_class_for_logout
    token_class if respond_to?(:token_class, true)
  rescue StandardError => e
    raise_logout_resolution_error!(:token_class, e)
  end

  def safe_current_session_public_id_for_logout
    session_token = safe_current_session_for_logout
    return session_token.public_id if session_token.respond_to?(:public_id) && session_token.public_id.present?

    return current_session_public_id if respond_to?(:current_session_public_id, true)

    current_session_public_id_from_refresh_cookie_for_logout
  rescue StandardError => e
    raise_logout_resolution_error!(:current_session_public_id, e)
  end

  def session_token_from_refresh_cookie_for_logout
    return nil unless respond_to?(:cookies, true)
    return nil unless respond_to?(:token_class, true)
    return nil unless respond_to?(:find_refresh_token_record, true)

    refresh_plain = cookies[AuthenticationBase::REFRESH_COOKIE_KEY].to_s
    refresh_public_id, = token_class.parse_refresh_token(refresh_plain)
    find_refresh_token_record(refresh_public_id)
  rescue StandardError
    nil
  end

  def current_session_public_id_from_refresh_cookie_for_logout
    session_token_from_refresh_cookie_for_logout&.public_id
  end

  def raise_logout_resolution_error!(component, exception)
    Rails.logger.warn(
      JitLogEvent.format(
        "auth.logout.resolution.failed",
        component: component,
        error_class: exception.class.name,
      ),
    )

    raise ResolutionError.new("Logout #{component} resolution failed"), cause: exception
  end

  def record_logout_audit(resource)
    return if resource.blank?
    return unless respond_to?(:record_audit, true)

    record_audit(AuthenticationBase::AUDIT_EVENTS[:logout_current_session], resource: resource)
  end

  def record_logout_all_sessions_audit(resource)
    return if resource.blank?
    return unless respond_to?(:record_audit, true)

    record_audit(AuthenticationBase::AUDIT_EVENTS[:logout_all_sessions], resource: resource)
  end
end
