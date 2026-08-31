# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        module Passkey
          class OptionsController < ::Auth::Org::ApplicationController
            include ::PasskeySignInFlow

            AUTHENTICATION_MODE = :guest
            declare_authentication_mode! :guest
            before_action :start_minimum_response_budget
            after_action :enforce_minimum_response_budget

            rate_limit(
              to: 5,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "auth_org_sign_in",
              name: "passkey_options_ip_burst",
              store: rate_limit_store,
              with: -> { render_rate_limited(retry_after: 60) },
            )
            rate_limit(
              to: 20,
              within: 15.minutes,
              by: -> { request.remote_ip },
              scope: "auth_org_sign_in",
              name: "passkey_options_ip_sustained",
              store: rate_limit_store,
              with: -> {
                render_rate_limited(retry_after: 900)
              },
            )

            def create = options

            private

            def before_passkey_options_request!
              verify_turnstile_stealth!
            end

            def passkey_identifier_required_error_key
              "errors.webauthn.identifier_required"
            end

            def normalized_passkey_identifier
              Operator.normalize_public_id(params[:identifier])
            end

            def valid_passkey_identifier?(identifier)
              Operator::PUBLIC_ID_FORMAT.match?(identifier)
            end

            def passkey_identifier_invalid_error_key
              "errors.webauthn.identifier_invalid"
            end

            def find_active_passkey_actor(identifier)
              normalized_identifier = Operator.normalize_public_id(identifier)
              return if normalized_identifier.blank?

              staff = Operator.find_by(public_id: normalized_identifier)
              staff if staff&.login_allowed?
            end
          end
        end
      end
    end
  end
end
