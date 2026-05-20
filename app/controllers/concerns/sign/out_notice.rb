# typed: false
# frozen_string_literal: true

module Sign
  module OutNotice
    extend ActiveSupport::Concern

    SIGN_OUT_NOTICE_SESSION_KEY = :sign_out_notice
    SIGN_OUT_NOTICE_TTL = 5.minutes

    private

    def issue_sign_out_notice!
      session[SIGN_OUT_NOTICE_SESSION_KEY] = {
        "expires_at" => SIGN_OUT_NOTICE_TTL.from_now.iso8601,
        "remaining_views" => 1,
      }
      flash[:notice] = t("sign.shared.sign_out.success")
    end

    def consume_sign_out_notice
      notice = session.delete(SIGN_OUT_NOTICE_SESSION_KEY)
      return unless notice.is_a?(Hash)

      expires_at = parse_sign_out_notice_time(notice["expires_at"])
      remaining_views = notice["remaining_views"].to_i
      return if expires_at.blank? || expires_at <= Time.current || remaining_views < 1

      notice.merge("expires_at" => expires_at)
    end

    def parse_sign_out_notice_time(value)
      Time.zone.iso8601(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
