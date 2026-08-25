# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        # PasskeysController handles Passkey-based user authentication.
        #
        # Flow:
        # 1. User visits /in/passkeys/new and enters their email
        # 2. POST /in/passkeys/options with email to get WebAuthn challenge
        # 3. Browser performs navigator.credentials.get()
        # 4. POST /in/passkeys/verification with credential + challenge_id
        # 5. Server verifies and establishes session via AuthenticationBase#log_in
        #
        # Note: Discoverable credentials (passwordless without identifier) are
        # planned for a future phase. Currently, email is required to look up
        # the user's registered passkeys.
        class PasskeysController < ::Auth::App::ApplicationController
          include ::SurfaceInertiaPage

          include ::PasskeySignInFlow

          include EmailValidation

          include IdentifierDetection

          include MinimumResponseBudget

          include SessionLimitGate

          include CloudflareTurnstile

          AUTHENTICATION_MODE = :guest
          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_app_sign_in",
            name: "passkey_options_ip_burst",
            store: rate_limit_store,
            only: :options,
            with: -> { render_rate_limited(retry_after: 60) },
          )
          rate_limit(
            to: 20,
            within: 15.minutes,
            by: -> { request.remote_ip },
            scope: "auth_app_sign_in",
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
            scope: "auth_app_sign_in",
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
            scope: "auth_app_sign_in",
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
          # Render login page with email input and passkey button
          def new
            render inertia: true, props: passkey_new_props
          end

          private

          def passkey_new_props
            scope = "sign.app.authentication.passkey.new"
            pt = signed_pt_param
            ri = current_region_identifier

            {
              title: page_t("#{scope}.page_title"),
              description: page_t("#{scope}.description"),
              panel: {
                options_url: auth_app_sign_in_passkey_options_path(pt: pt, ri: ri),
                verification_url: auth_app_sign_in_passkey_verification_path(pt: pt, ri: ri),
                region: ri.to_s,
                identifier_param: "identifier",
                # The stealth site key is public by design and the ERB already published it in the
                # rendered HTML; the secret key and the token verification stay server side.
                turnstile_site_key: JitSecurityTurnstileConfig.stealth_site_key.to_s,
                turnstile_error_message: t("turnstile_error"),
                field: {
                  label: page_t("#{scope}.pii_label"),
                  placeholder: page_t("#{scope}.pii_placeholder"),
                },
                submit_label: page_t("#{scope}.submit"),
              },
              back_link: {
                label: t("sign.app.authentication.new.back"),
                href: auth_app_sign_in_path(pt: pt, ri: ri),
              },
            }
          end

          def find_active_passkey_actor(identifier)
            user = find_user_by_identifier(identifier)
            user if user&.active?
          end

          def passkey_identifier_required_error_key
            "errors.webauthn.pii_required"
          end

          def before_passkey_options_request!
            verify_turnstile_stealth!
          end

          def allow_passkey_sign_in?(passkey)
            return true if passkey.user.has_verified_pii?

            Rails.logger.info(
              JitLogEvent.format(
                "authentication.passkey.failed",
                reason: "verified_pii_missing",
                user_id: passkey.user_id,
                ip_address: request.remote_ip,
                ri: current_region_identifier,
              ),
            )
            render_error("errors.webauthn.credential_not_found", :unauthorized)
            false
          end

          def perform_passkey_sign_in(passkey)
            pt = retrieve_pt_for_checkpoint
            AuthenticationSessionCommitter.call(
              controller: self, resource: passkey.user, pt: pt, ri: current_region_identifier, auth_method: "passkey",
            )
          end

          def handle_domain_specific_login_status(result)
            case result[:status]
            when :mfa_required
              render json: { status: "mfa_required", redirect_url: result[:redirect_path] }, status: :ok
              true
            when :session_limit_hard_reject
              render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
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
              redirect_url: auth_app_sign_in_session_path,
              message: I18n.t("sign.app.in.session.restricted_notice"),
            }, status: :ok
          end

          def passkey_checkpoint_redirect_url
            auth_app_sign_in_check_path(
              pt: retrieve_pt_for_checkpoint,
              ri: current_region_identifier,
            )
          end

          def passkey_default_redirect_url
            base_app_identity_url(ri: current_region_identifier, host: base_authority_host)
          end

          def minimum_response_budget_enabled?
            action_name == "options"
          end
        end
      end
    end
  end
end
