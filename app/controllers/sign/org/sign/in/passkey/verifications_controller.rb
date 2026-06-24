# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Sign
      module In
        module Passkey
          class VerificationsController < ::Sign::Org::ApplicationController
            include SignPasskeySignInEndpoint

            AUTHENTICATION_MODE = :guest
            declare_authentication_mode! :guest
            before_action :start_minimum_response_budget
            after_action :enforce_minimum_response_budget

            rate_limit(
              to: 5,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "sign_org_sign_in",
              name: "passkey_verification_ip_burst",
              store: rate_limit_store,
              with: -> {
                render_rate_limited(rule_name: "sign_org_sign_in_passkey_verification_ip_burst", retry_after: 60)
              },
            )
            rate_limit(
              to: 20,
              within: 15.minutes,
              by: -> { request.remote_ip },
              scope: "sign_org_sign_in",
              name: "passkey_verification_ip_sustained",
              store: rate_limit_store,
              with: -> {
                render_rate_limited(rule_name: "sign_org_sign_in_passkey_verification_ip_sustained", retry_after: 900)
              },
            )

            def create = verification

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

            def active_passkeys_for_actor(staff)
              staff.staff_passkeys.where(status_id: OperatorPasskeyStatus::ACTIVE)
            end

            def passkey_challenge_actor_id_key
              "staff_id"
            end

            def passkey_sign_in_model
              OperatorPasskey
            end

            def passkey_belongs_to_challenge_actor?(passkey, actor_id)
              passkey.staff_id == actor_id
            end

            def passkey_owner_mismatch_log_message
              "WebAuthn: Credential not found or staff mismatch"
            end

            def perform_passkey_sign_in(passkey)
              establish_signed_in_session!(
                passkey.staff, pt: retrieve_pt_for_checkpoint, ri: current_region_identifier, auth_method: "passkey",
              )
            end

            def handle_domain_specific_login_status(result)
              case result[:status]
              when :session_limit_hard_reject
                render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
                true
              when :session_limit_exceeded
                issue_session_limit_gate!(pt: request.fullpath, flow: "in.passkeys.session")
                render json: {
                  status: "session_limit_exceeded",
                  redirect_url: new_sign_org_sign_in_passkey_path,
                }, status: :ok
                true
              else
                false
              end
            end

            def render_passkey_restricted_success(_result)
              render json: {
                status: "session_restricted",
                redirect_url: sign_org_sign_in_session_path,
              }, status: :ok
            end

            def passkey_checkpoint_redirect_url
              sign_org_sign_in_check_path(pt: retrieve_pt_for_checkpoint, ri: current_region_identifier)
            end

            def passkey_default_redirect_url
              sign_org_root_path(ri: current_region_identifier)
            end
          end
        end
      end
    end
  end
end
