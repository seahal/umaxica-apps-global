# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        class PasskeysController < ::Auth::Com::ApplicationController
          include ::PasskeySignInFlow

          include EmailValidation

          include IdentifierDetection

          include MinimumResponseBudget

          include SessionLimitGate

          include CloudflareTurnstile
          include ::SurfaceInertiaPage
          include ::TurnstilePageProps

          AUTHENTICATION_MODE = :guest
          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_com_sign_in",
            name: "passkey_options_ip_burst",
            store: rate_limit_store,
            only: :options,
            with: -> { render_rate_limited(retry_after: 60) },
          )
          rate_limit(
            to: 20,
            within: 15.minutes,
            by: -> { request.remote_ip },
            scope: "auth_com_sign_in",
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
            scope: "auth_com_sign_in",
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
            scope: "auth_com_sign_in",
            name: "passkey_verification_ip_sustained",
            store: rate_limit_store,
            only: :verification,
            with: -> {
              render_rate_limited(retry_after: 900)
            },
          )
          before_action :start_minimum_response_budget
          after_action :enforce_minimum_response_budget

          def new
            render inertia: true, props: sign_in_passkey_new_props
          end

          private

          def sign_in_passkey_new_props
            pt = signed_pt_param
            ri = current_region_identifier

            {
              title: t("sign.app.authentication.passkey.new.page_title"),
              description: t("sign.app.authentication.passkey.new.description"),
              panel: {
                options_url: auth_com_sign_in_passkey_options_path(pt: pt, ri: ri),
                verification_url: auth_com_sign_in_passkey_verification_path(pt: pt, ri: ri),
                region: ri.to_s,
                identifier_param: "identifier",
                turnstile_site_key: turnstile_stealth_props.fetch(:site_key),
                turnstile_error_message: t("turnstile_error"),
                field: {
                  label: t("sign.app.authentication.passkey.new.pii_label"),
                  placeholder: t("sign.app.authentication.passkey.new.pii_placeholder"),
                  min_length: 0,
                  max_length: 255,
                  pattern: ".*",
                },
                submit_label: t("sign.app.authentication.passkey.new.submit"),
              },
              back_link: {
                label: t("sign.app.authentication.new.back"),
                href: auth_com_sign_in_path(pt: pt, ri: ri),
              },
            }
          end

          def identity_email_model
            VisitorEmail
          end

          def identity_telephone_model
            VisitorTelephone
          end

          def identity_from_email_record(record)
            record&.visitor
          end

          def identity_from_telephone_record(record)
            record&.visitor
          end

          def find_active_passkey_actor(identifier)
            visitor = find_user_by_identifier(identifier)
            visitor if visitor&.active?
          end

          def passkey_identifier_required_error_key
            "errors.webauthn.pii_required"
          end

          def before_passkey_options_request!
            verify_turnstile_stealth!
          end

          def allow_passkey_sign_in?(passkey)
            return true if passkey.visitor.has_verified_pii?

            Rails.logger.info(
              JitLogEvent.format(
                "authentication.passkey.failed",
                reason: "verified_pii_missing",
                visitor_id: passkey.visitor_id,
                ip_address: request.remote_ip,
                ri: current_region_identifier,
              ),
            )
            render_error("errors.webauthn.credential_not_found", :unauthorized)
            false
          end

          def perform_passkey_sign_in(passkey)
            pt = retrieve_pt_for_checkpoint
            establish_signed_in_session!(
              passkey.visitor, pt: pt, ri: current_region_identifier, auth_method: "passkey",
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
              redirect_url: auth_com_sign_in_session_path,
              message: I18n.t("sign.app.in.session.restricted_notice"),
            }, status: :ok
          end

          def passkey_checkpoint_redirect_url
            auth_com_sign_in_check_path(
              pt: retrieve_pt_for_checkpoint,
              ri: current_region_identifier,
            )
          end

          def passkey_default_redirect_url
            base_com_identity_url(ri: current_region_identifier, host: base_authority_host)
          end

          def minimum_response_budget_enabled?
            action_name == "options"
          end
        end
      end
    end
  end
end
