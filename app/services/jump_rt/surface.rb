# typed: false
# frozen_string_literal: true

module JumpRt
  module Surface
    module_function

    HOST_ENV = {
      "SIGN_APP" => ["SIGN_SERVICE_URL", "id.umaxica.app"],
      "SIGN_COM" => ["SIGN_CORPORATE_URL", "id.umaxica.com"],
      "SIGN_ORG" => ["SIGN_STAFF_URL", "id.umaxica.org"],
      "ACME_APP" => ["APEX_SERVICE_URL", "www.umaxica.app"],
      "ACME_COM" => ["APEX_CORPORATE_URL", "www.umaxica.com"],
      "ACME_ORG" => ["APEX_STAFF_URL", "www.umaxica.org"],
      "CORE_APP" => ["CORE_SERVICE_URL", "www.jp.umaxica.app"],
      "CORE_COM" => ["CORE_CORPORATE_URL", "www.jp.umaxica.com"],
      "CORE_ORG" => ["CORE_STAFF_URL", "www.jp.umaxica.org"],
    }.freeze

    def issuer_origin(namespace)
      env_key, fallback = HOST_ENV.fetch(normalize_namespace(namespace))
      "https://#{normalize_host(ENV.fetch(env_key, fallback))}"
    end

    def namespace_for_controller(controller_class_name)
      service =
        case controller_class_name.to_s
        when /\ASign::/ then "SIGN"
        when /\AApex::/ then "ACME"
        when /\ACore::/ then "CORE"
        end
      surface =
        case controller_class_name.to_s
        when /::App::/ then "APP"
        when /::Com::/ then "COM"
        when /::Org::/ then "ORG"
        end
      return nil if service.blank? || surface.blank?

      "#{service}_#{surface}"
    end

    def normalize_namespace(namespace)
      value = namespace.to_s.upcase
      raise ArgumentError, "unsupported Jump RT issuer surface: #{namespace.inspect}" unless HOST_ENV.key?(value)

      value
    end

    def normalize_host(host)
      host.to_s.strip.sub(/\Ahttps?:\/\//, "").split("/").first
    end
  end
end
