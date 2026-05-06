# typed: false
# frozen_string_literal: true

module Authentication
  module Customer
    extend ActiveSupport::Concern

    include Authentication::Base

    ACCESS_COOKIE_KEY = Authentication::Base::ACCESS_COOKIE_KEY
    REFRESH_COOKIE_KEY = Authentication::Base::REFRESH_COOKIE_KEY
    DEVICE_COOKIE_KEY = Authentication::Base::DEVICE_COOKIE_KEY
    ACCESS_TOKEN_TTL = Authentication::Base::ACCESS_TOKEN_TTL
    REFRESH_TOKEN_TTL = Authentication::Base::REFRESH_TOKEN_TTL
    AUDIT_EVENTS = Authentication::Base::AUDIT_EVENTS

    included do
      helper_method :current_customer, :logged_in?, :active_customer?,
                    :logged_in_customer? if respond_to?(:helper_method)
      alias_method :current_customer, :current_resource
      alias_method :authenticate_customer!, :authenticate!
      alias_method :logged_in_customer?, :logged_in?
      include ::AuthorizationAudit
    end

    def audit_customer_login_failed(customer)
      record_audit(AUDIT_EVENTS[:login_failed], resource: customer, actor: nil) if customer
    end

    def active_customer?
      current_customer.present? && current_customer.active?
    end

    def am_i_user?
      false
    end

    def am_i_staff?
      false
    end

    def am_i_owner?
      false
    end

    private

    def resource_class
      ::Customer
    end

    def token_class
      CustomerToken
    end

    def audit_class
      ::UserChronicle
    end

    def resource_type
      "customer"
    end

    def resource_foreign_key
      :customer_id
    end

    def max_sessions_for_resource(resource)
      return CustomerToken::MAX_SESSIONS_PER_CUSTOMER if resource.is_a?(::Customer)

      super
    end

    def test_header_key
      Auth::IoKeys::Headers::TEST_CURRENT_RESOURCE
    end

    def record_audit(event_id, resource:, actor: resource)
      return unless resource && event_id

      normalized_event_id =
        case event_id.to_s
        when "LOGGED_IN" then UserChronicleEvent::LOGGED_IN
        when "LOGGED_OUT" then UserChronicleEvent::LOGGED_OUT
        when "LOGIN_FAILED" then UserChronicleEvent::LOGIN_FAILED
        when "TOKEN_REFRESHED" then UserChronicleEvent::TOKEN_REFRESHED
        else event_id
        end

      ChronicleRecord.connected_to(role: :writing) do
        UserChronicle.create!(
          actor_id: actor&.id || 0,
          actor_type: actor&.class&.name || "Customer",
          subject_id: resource.id.to_s,
          subject_type: "Customer",
          event_id: normalized_event_id,
          level_id: UserChronicleLevel::NOTHING,
          ip_address: request_ip_address,
          occurred_at: Time.current,
          context: {},
        )
      end
    rescue StandardError => e
      Rails.logger.error("[Authentication::Customer] audit write failed: #{e.class}: #{e.message}")
      false
    end

    def sign_in_url_with_return(return_to)
      new_sign_com_in_url(
        rt: return_to,
        host: ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
        protocol: request.protocol,
      )
    end
  end
end
