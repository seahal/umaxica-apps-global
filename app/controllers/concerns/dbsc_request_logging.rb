# typed: false
# frozen_string_literal: true

module DbscRequestLogging
  extend ActiveSupport::Concern

  private

  def log_dbsc_request_observability!
    headers = dbsc_observable_headers
    return if headers.empty?

    Rails.logger.info("[dbsc] #{request.request_method} #{request.fullpath} headers=#{headers.inspect}")
  end

  def dbsc_observable_headers
    header_names = [
      AuthIoKeys::Headers::DBSC_REGISTRATION,
      AuthIoKeys::Headers::DBSC_RESPONSE,
      AuthIoKeys::Headers::DBSC_SESSION_ID,
      AuthIoKeys::Headers::DBSC_CHALLENGE,
      PreferenceIoKeys::Headers::DBSC_REGISTRATION,
      PreferenceIoKeys::Headers::DBSC_RESPONSE,
      PreferenceIoKeys::Headers::DBSC_SESSION_ID,
      PreferenceIoKeys::Headers::DBSC_CHALLENGE,
      "Secure-Session-Registration",
      "Secure-Session-Response",
      "Secure-Session-Skipped",
      "Secure-Session-Id",
      "Secure-Session-Challenge",
      "Sec-Secure-Session-Id",
      "Sec-Secure-Session-Challenge",
      "Sec-Session-Registration",
      "Sec-Session-Response",
      "Sec-Session-Skipped",
      "Sec-Session-Id",
      "Sec-Session-Challenge",
    ].uniq

    header_names.each_with_object({}) do |name, result|
      value = request.headers[name]
      next if value.blank?

      result[name] = dbsc_truncated_header_value(value)
    end
  end

  def dbsc_truncated_header_value(value)
    value.to_s.tr("\n\r", " ")[0, 160]
  end
end
