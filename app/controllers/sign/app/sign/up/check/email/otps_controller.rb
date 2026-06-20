# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module Up
        module Check
          module Email
            class OtpsController < ::Sign::App::Sign::Up::EmailsController
              include SignUpExplicitStepControllerSupport

              AUTHENTICATION_MODE = :guest
              skip_before_action :enforce_email_flow!

              def show
                return unless load_gate_context!(gate_for_show)

                @user_email = current_registration_email
                return redirect_invalid_session unless valid_email_session?

                render "sign/app/sign/up/emails/edit"
              end

              def create
                return unless load_gate_context!(gate_for_create)

                @user_email = current_registration_email
                return redirect_invalid_session unless @user_email

                result = issue_otp_ceremony!
                return render_otp_ceremony_result(result) unless result.success?

                redirect_to(sign_app_sign_up_check_email_otp_path(ri: params[:ri], pt: signed_pt_param))
              end

              def update
                return unless load_gate_context!(gate_for_update)

                @user_email = current_registration_email
                return redirect_invalid_session unless valid_email_session?
                return render_code_required unless validate_code_present

                result = verify_otp_ceremony!
                log_email_otp_rejection(result) unless result.success?
                return handle_locked_result if result.status == :locked
                return render_otp_ceremony_result(result) unless result.success?

                @user_email.update!(user_email_status_id: ClientEmailStatus::VERIFIED_WITH_SIGN_UP)
                complete_update_and_redirect
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def sign_up_surface = :app

              def sign_up_ticket_class = ClientSignUpFlow

              def sign_up_sequence_session_key = :sign_app_up_sequence_id

              def sign_up_family = "email"

              def sign_up_step = :otp

              def issue_otp_ceremony!
                SignOtpCeremony.issue!(
                  purpose: :sign_up,
                  surface: :app,
                  channel: :email,
                  subject: @sign_up_ticket,
                  destination: @user_email.address,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def verify_otp_ceremony!
                SignOtpCeremony.verify!(
                  purpose: :sign_up,
                  surface: :app,
                  channel: :email,
                  subject: @sign_up_ticket,
                  destination: @user_email.address,
                  code: params.dig("client_email", "pass_code") || params.dig("user_email", "pass_code"),
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def render_otp_ceremony_result(result)
                if result.status == :rate_limited
                  @user_email.errors.add(:base, t("sign.app.registration.email.create.otp_resend_too_soon"))
                  return render "sign/app/sign/up/emails/edit", status: :too_many_requests
                end

                @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
                render "sign/app/sign/up/emails/edit", status: :unprocessable_content
              end

              def log_email_otp_rejection(result)
                reason =
                  case result.status
                  when :blank_code then "otp_blank"
                  when :invalid_code then "otp_mismatch"
                  when :locked then "otp_locked"
                  when :rate_limited then "otp_attempts_exceeded"
                  when :missing_otp then "otp_candidate_not_found"
                  else "unexpected_error"
                  end

                log_sign_signup_event(
                  "sign.signup.email.otp.rejected",
                  sign_signup_request_flags.merge(
                    step: "email_otp",
                    reason: reason,
                    attempts_remaining: @user_email.respond_to?(:otp_attempts_remaining) ?
                      @user_email.otp_attempts_remaining : nil,
                    **sign_signup_safe_otp_state(@user_email),
                  ).compact,
                )
              end

              def redirect_invalid_session
                reset_email_flow!
                @user_email ||= ClientEmail.new
                @user_email.errors.add(:base, t("sign.app.registration.email.edit.session_expired"))
                render "sign/app/sign/up/emails/edit", status: :unprocessable_content
              end

              def handle_locked_result
                reset_email_flow!
                @user_email.errors.add(:base, t("sign.app.registration.email.update.attempts_exceeded"))
                render "sign/app/sign/up/emails/edit", status: :too_many_requests
              end
            end
          end
        end
      end
    end
  end
end
