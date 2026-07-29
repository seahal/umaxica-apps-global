# typed: false
# frozen_string_literal: true

module EnforcementRecoveryCeremonyCookie
  extend ActiveSupport::Concern

  COOKIE_BASENAME = "enforcement_recovery"

  private

  def recovery_ceremony_cookie_name
    AuthenticationCookieName.with_host_prefix(COOKIE_BASENAME, production: JitSessionCookieConfig.force_secure?)
  end

  def recovery_ceremony_cookie_options
    authentication_cookie_service.auth_cookie_options.merge(expires: EnforcementRecoveryCeremonyRecordable::TTL.from_now)
  end

  def write_recovery_ceremony_cookie!(ceremony)
    cookies[recovery_ceremony_cookie_name] = recovery_ceremony_cookie_options.merge(
      value: "#{ceremony.public_id}:#{ceremony.plaintext_token}",
    )
  end

  def current_recovery_ceremony
    public_id, token = cookies[recovery_ceremony_cookie_name].to_s.split(":", 2)
    recovery_ceremony_class.authenticate(public_id: public_id, token: token)
  end

  def clear_recovery_ceremony_cookie!
    cookies.delete(recovery_ceremony_cookie_name, authentication_cookie_service.auth_cookie_deletion_options)
  end
end
