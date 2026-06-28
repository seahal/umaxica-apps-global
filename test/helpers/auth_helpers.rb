# typed: false
# frozen_string_literal: true

module AuthHelpers
  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||= auth_helper_resource_type(resource)

    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    boot_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    service =
      case normalized
      when boot_hosts.acme_service.host, boot_hosts.acme_corporate.host, boot_hosts.acme_staff.host then "ACME"
      when boot_hosts.base_service.host, boot_hosts.base_corporate.host, boot_hosts.base_staff.host then "BASE"
      when boot_hosts.core_service.host, boot_hosts.core_corporate.host, boot_hosts.core_staff.host then "CORE"
      when boot_hosts.sign_service.host, boot_hosts.sign_corporate.host, boot_hosts.sign_staff.host then "SIGN"
      else
        "SIGN"
      end

    surface =
      if %w(SIGN BASE).include?(service)
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end

    "surface:#{service}_#{surface}"
  end

  private

  def auth_helper_resource_type(resource)
    case resource
    when Client then "client"
    when Operator then "operator"
    when Visitor then "visitor"
    end
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include AuthHelpers
end
