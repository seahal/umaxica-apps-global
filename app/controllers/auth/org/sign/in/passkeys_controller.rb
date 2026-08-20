# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        # PasskeysController handles Passkey-based operator authentication.
        #
        # Flow:
        # 1. Operator visits /in/passkeys/new and enters their operator public_id
        # 2. POST /in/passkeys/options with identifier to get WebAuthn challenge
        # 3. Browser performs navigator.credentials.get()
        # 4. POST /in/passkeys/verification with credential + challenge_id
        # 5. Server verifies and establishes session via AuthenticationBase#log_in
        #
        # Note: Discoverable credentials (passwordless without identifier) are
        # planned for a future phase. Currently, identifier is required to look up
        # the operator's registered passkeys.
        class PasskeysController < ::Auth::Org::ApplicationController
          include ::PasskeySignInFlow

          include MinimumResponseBudget

          include SessionLimitGate

          include CloudflareTurnstile

          include ::TurnstilePageProps
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :guest
          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_org_sign_in",
            name: "passkey_options_ip_burst",
            store: rate_limit_store,
            only: :options,
            with: -> { render_rate_limited(retry_after: 60) },
          )
          rate_limit(
            to: 20,
            within: 15.minutes,
            by: -> { request.remote_ip },
            scope: "auth_org_sign_in",
            name: "passkey_options_ip_sustained",
            store: rate_limit_store,
            only: :options,
            with: -> {
              render_rate_limited(retry_after: 900)
            },
          )
          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_org_sign_in",
            name: "passkey_verification_ip_burst",
            store: rate_limit_store,
            only: :verification,
            with: -> {
              render_rate_limited(retry_after: 60)
            },
          )
          rate_limit(
            to: 20,
            within: 15.minutes,
            by: -> { request.remote_ip },
            scope: "auth_org_sign_in",
            name: "passkey_verification_ip_sustained",
            store: rate_limit_store,
            only: :verification,
            with: -> {
              render_rate_limited(retry_after: 900)
            },
          )
          before_action :start_minimum_response_budget
          after_action :enforce_minimum_response_budget

          # GET /in/passkeys/new
          # Render login page with identifier input and passkey button
          def new
            render inertia: true, props: passkey_sign_in_props
          end

          private

          def passkey_sign_in_props
            pt = signed_pt_param
            region = current_region_identifier

            {
              title: t("sign.org.authentication.passkey.new.page_title"),
              description: t("sign.org.authentication.passkey.new.description"),
              panel: {
                options_url: auth_org_sign_in_passkey_options_path(pt: pt, ri: region),
                verification_url: auth_org_sign_in_passkey_verification_path(pt: pt, ri: region),
                region: region.to_s,
                identifier_param: "identifier",
                turnstile_site_key: turnstile_site_key(:CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY),
                turnstile_error_message: t("turnstile_error"),
                field: {
                  label: t("sign.org.authentication.passkey.new.identifier_label"),
                  placeholder: t("sign.org.authentication.passkey.new.identifier_placeholder"),
                  min_length: Operator::PUBLIC_ID_LENGTH,
                  max_length: Operator::PUBLIC_ID_LENGTH,
                  pattern: "[0-9A-FGHJKMNPQRSTVWXYZ]{16}",
                },
                submit_label: t("sign.org.authentication.passkey.new.submit"),
              },
              back_link: {
                label: t("sign.org.authentication.new.back"),
                href: auth_org_sign_in_path(pt: pt, ri: region),
              },
            }
          end

          def before_passkey_options_request!
            verify_turnstile_stealth!
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
                redirect_url: new_auth_org_sign_in_passkey_path,
              }, status: :ok
              true
            else
              false
            end
          end

          def passkey_success_restricted?(result)
            result[:restricted]
          end

          def render_passkey_restricted_success(_result)
            render json: {
              status: "session_restricted",
              redirect_url: auth_org_sign_in_session_path,
            }, status: :ok
          end

          def passkey_checkpoint_redirect_url
            auth_org_sign_in_check_path(pt: retrieve_pt_for_checkpoint, ri: current_region_identifier)
          end

          def passkey_default_redirect_url
            auth_org_root_path(ri: current_region_identifier)
          end

          def minimum_response_budget_enabled?
            action_name == "options"
          end
        end
      end
    end
  end
end
