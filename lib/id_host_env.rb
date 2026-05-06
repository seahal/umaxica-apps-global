# typed: false
# frozen_string_literal: true

module IdHostEnv
  class MissingHostError < StandardError; end

  module_function

  def service_url
    ENV["ID_SERVICE_URL"].presence
  end

  def corporate_url
    ENV["ID_CORPORATE_URL"].presence
  end

  def staff_url
    ENV["ID_STAFF_URL"].presence
  end

  def validate!
    missing = []
    missing << "ID_SERVICE_URL" if service_url.blank?
    missing << "ID_CORPORATE_URL" if corporate_url.blank?
    missing << "ID_STAFF_URL" if staff_url.blank?
    return if missing.empty?

    raise MissingHostError, "Missing required id host env: #{missing.join(", ")}"
  end
end
