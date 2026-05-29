# typed: false
# frozen_string_literal: true

module Authentication
  module Operator
    extend ActiveSupport::Concern

    include Authentication::Base

    ACCESS_COOKIE_KEY = Authentication::Base::ACCESS_COOKIE_KEY
    REFRESH_COOKIE_KEY = Authentication::Base::REFRESH_COOKIE_KEY
    ACCESS_TOKEN_TTL = Authentication::Base::ACCESS_TOKEN_TTL
    REFRESH_TOKEN_TTL = Authentication::Base::REFRESH_TOKEN_TTL
    AUDIT_EVENTS = Authentication::Base::AUDIT_EVENTS

    included do
      helper_method :current_operator, :logged_in?, :active_operator?,
                    :logged_in_operator? if respond_to?(:helper_method)
      alias_method :current_operator, :current_resource
      alias_method :authenticate_operator!, :authenticate!
      alias_method :logged_in_operator?, :logged_in?
      include ::AuthorizationAudit
    end

    def audit_operator_login_failed(operator)
      record_audit(AUDIT_EVENTS[:login_failed], resource: operator, actor: nil) if operator
    end

    def active_operator?
      current_operator.present? && current_operator.active?
    end

    def am_i_user?
      false
    end

    def am_i_operator?
      true
    end

    def am_i_owner?
      false
    end

    private

    def resource_class
      ::Operator
    end

    def token_class
      OperatorToken
    end

    def audit_class
      ::OperatorChronicle
    end

    def resource_type
      "operator"
    end

    def resource_foreign_key
      :staff_id
    end

    def sign_in_url_with_pt(return_to)
      _ = return_to
      new_sign_org_in_url(
        host: sign_org_redirect_host,
        protocol: "https",
      )
    end

    def sign_org_redirect_host
      configured_hosts =
        %w(SIGN_STAFF_URL ID_STAFF_URL).filter_map do |key|
          Common::Redirect.normalize_host(ENV[key])
        end

      request_host = Common::Redirect.normalize_host(request.host_with_port)
      return request_host if configured_hosts.include?(request_host)

      configured_hosts.first || "id.org.localhost"
    end
  end
end
