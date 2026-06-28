# typed: false
# frozen_string_literal: true

module JitIdHostEnv
  class MissingHostError < StandardError; end

  module_function

  def service_url
    ENV["ID_SERVICE_URL"].presence
  end

  def corporate_url
    ENV["PRIVATE_SIGN_CORPORATE_URL"].presence || ENV["SIGN_CORPORATE_URL"].presence
  end

  def staff_url
    ENV["ID_STAFF_URL"].presence
  end

  def validate!
    missing_keys = []
    missing_keys << "ID_SERVICE_URL" if service_url.blank?
    missing_keys << "SIGN_CORPORATE_URL" if corporate_url.blank?
    missing_keys << "ID_STAFF_URL" if staff_url.blank?
    return if missing_keys.empty?

    raise MissingHostError, "Missing required id host env: #{missing_keys.join(", ")}"
  end
end
