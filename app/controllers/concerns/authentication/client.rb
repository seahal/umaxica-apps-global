# typed: false
# frozen_string_literal: true

module Authentication
  module Client
    extend ActiveSupport::Concern

    include Authentication::Base

    ACCESS_COOKIE_KEY = Authentication::Base::ACCESS_COOKIE_KEY
    REFRESH_COOKIE_KEY = Authentication::Base::REFRESH_COOKIE_KEY
    DEVICE_COOKIE_KEY = Authentication::Base::DEVICE_COOKIE_KEY
    ACCESS_TOKEN_TTL = Authentication::Base::ACCESS_TOKEN_TTL
    REFRESH_TOKEN_TTL = Authentication::Base::REFRESH_TOKEN_TTL
    AUDIT_EVENTS = Authentication::Base::AUDIT_EVENTS

    included do
      helper_method :current_client, :logged_in?, :active_client?,
                    :logged_in_client? if respond_to?(:helper_method)
      alias_method :current_client, :current_resource
      alias_method :authenticate_client!, :authenticate!
      alias_method :logged_in_client?, :logged_in?
      include ::AuthorizationAudit
    end

    def audit_client_login_failed(client)
      record_audit(AUDIT_EVENTS[:login_failed], resource: client, actor: nil) if client
    end

    def active_client?
      current_client.present? && current_client.active?
    end

    def am_i_client?
      true
    end

    def am_i_staff?
      false
    end

    def am_i_owner?
      false
    end

    private

    def resource_class
      ::Client
    end

    def token_class
      ClientToken
    end

    def audit_class
      ::ClientChronicle
    end

    def resource_type
      "client"
    end

    def resource_foreign_key
      :user_id
    end

    def sign_in_url_with_return(return_to)
      new_sign_app_in_url(
        rt: return_to,
        host: sign_app_redirect_host,
        protocol: request.protocol,
      )
    end

    def sign_app_redirect_host
      configured_hosts =
        %w(SIGN_SERVICE_URL ID_SERVICE_URL).filter_map do |key|
          Common::Redirect.normalize_host(ENV[key])
        end

      request_host = Common::Redirect.normalize_host(request.host_with_port)
      return request_host if configured_hosts.include?(request_host)

      configured_hosts.first || "id.app.localhost"
    end
  end
end
