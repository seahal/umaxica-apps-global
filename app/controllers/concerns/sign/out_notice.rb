# typed: false
# frozen_string_literal: true

module Sign
  module OutNotice
    extend ActiveSupport::Concern

    SIGN_OUT_NOTICE_SESSION_KEY = :sign_out_notice
    SIGN_OUT_NOTICE_TTL = 5.minutes

    included do
      helper_method :sign_out_completed_description if respond_to?(:helper_method)
    end

    private

    def prepare_sign_out_completion_notice!
      @sign_out_access_expires_at = current_sign_out_access_expires_at
    end

    def issue_sign_out_notice!
      access_expires_at = @sign_out_access_expires_at || current_sign_out_access_expires_at
      notice = {
        "expires_at" => SIGN_OUT_NOTICE_TTL.from_now.iso8601,
        "remaining_views" => 1,
      }
      notice["access_expires_at"] = access_expires_at.iso8601 if access_expires_at.present?
      session[SIGN_OUT_NOTICE_SESSION_KEY] = notice

      flash[:notice] =
        if access_expires_at.present?
          t(
            "sign.shared.sign_out.success",
            expires_at: l(access_expires_at, format: :short),
          )
        else
          t("sign.shared.sign_out.completed_title")
        end
    end

    def consume_sign_out_notice
      notice = session.delete(SIGN_OUT_NOTICE_SESSION_KEY)
      return unless notice.is_a?(Hash)

      expires_at = parse_sign_out_notice_time(notice["expires_at"])
      access_expires_at = parse_sign_out_notice_time(notice["access_expires_at"])
      remaining_views = notice["remaining_views"].to_i
      return if expires_at.blank? || expires_at <= Time.current || remaining_views < 1

      notice.merge("expires_at" => expires_at, "access_expires_at" => access_expires_at)
    end

    def sign_out_completed_description
      access_expires_at = @sign_out_access_expires_at || @sign_out_notice&.fetch("access_expires_at", nil)
      return if access_expires_at.blank?

      t(
        "sign.shared.sign_out.completed_description",
        expires_at: l(access_expires_at, format: :short),
      )
    end

    def current_sign_out_access_expires_at
      access_expires_at_from_claims(Actor.authn.access_claims) ||
        access_expires_at_from_current_cookie
    end

    def access_expires_at_from_current_cookie
      return unless respond_to?(:extract_access_token, true)
      return unless request&.host.present?
      return unless respond_to?(:resource_type, true)

      token = extract_access_token(Authentication::Base::ACCESS_COOKIE_KEY)
      return if token.blank?

      payload = Authentication::Base::Token.decode_allow_expired(
        token,
        host: request.host,
        resource_type: resource_type,
        jwt_issuer_id: auth_jwt_issuer_id_for_sign_out_notice,
      )
      access_expires_at_from_claims(payload)
    end

    def auth_jwt_issuer_id_for_sign_out_notice
      auth_jwt_issuer_id if respond_to?(:auth_jwt_issuer_id, true)
    end

    def access_expires_at_from_claims(claims)
      exp = claims&.dig("exp")
      return if exp.blank?

      Time.zone.at(Integer(exp))
    rescue ArgumentError, TypeError
      nil
    end

    def parse_sign_out_notice_time(value)
      Time.zone.iso8601(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
