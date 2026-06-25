# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module Up
        module Check
          module Apple
            class ConfirmationsController < ::Sign::App::ApplicationController
              include SignUpExplicitStepControllerSupport

              AUTHENTICATION_MODE = :open

              def show
                return unless load_gate_context!(gate_for_show)

                render "sign/app/sign/up/check/social/confirmations/show"
              end

              def update
                return unless load_gate_context!(gate_for_update)
                return render plain: "social_signup_confirmation_required", status: :unprocessable_content unless
                  ActiveModel::Type::Boolean.new.cast(params[:confirm_new_social_identity])
                return render_turnstile_failure unless verify_social_signup_turnstile!

                clear_current_requirement!
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def sign_up_surface = :app

              def sign_up_ticket_class = ClientSignUpFlow

              def sign_up_sequence_session_key = :sign_app_up_sequence_id

              def sign_up_family = "apple"

              def sign_up_step = :confirmation

              def verify_social_signup_turnstile!
                result =
                  JitSecurityTurnstileVerifier.verify_for_ceremony(
                    token: request.request_parameters["cf-turnstile-response"].to_s,
                    remote_ip: request.remote_ip,
                    ceremony_id: @sign_up_ticket.public_id,
                    expected_action: "social_signup_confirmation",
                    expected_hostname: request.host,
                    expected_cdata: @sign_up_ticket.public_id,
                    mode: :visible,
                  )
                log_social_signup_turnstile_failure(result) unless result["success"]
                result["success"]
              end

              def render_turnstile_failure
                render plain: I18n.t("turnstile_error"), status: :unprocessable_content
              end

              def log_social_signup_turnstile_failure(result)
                Rails.logger.info(
                  JitLogEvent.format(
                    "sign_up.social_confirmation.turnstile_failed",
                    provider: sign_up_family,
                    host: request.host,
                    flow_id_present: @sign_up_ticket&.public_id.present?,
                    token_present: request.request_parameters["cf-turnstile-response"].present?,
                    error: result["error"],
                    error_codes: result["error-codes"],
                    action: result["action"],
                    hostname: result["hostname"],
                    cdata_present: result["cdata"].present?,
                  ),
                )
              end
            end
          end
        end
      end
    end
  end
end
