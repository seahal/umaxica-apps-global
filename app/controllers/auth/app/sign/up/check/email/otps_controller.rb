# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Email
            class OtpsController < ::Auth::App::Sign::Up::EmailsController
              include SignUpExplicitStepControllerSupport

              AUTHENTICATION_MODE = :guest
              skip_before_action :enforce_email_flow!

              def show
                if dummy_existing_email_flow?
                  @user_email = ClientEmail.new
                  return render "auth/app/sign/up/emails/edit" if valid_email_session?

                  return redirect_invalid_session
                end

                return unless load_gate_context!(gate_for_show)

                @user_email = current_registration_email
                return redirect_invalid_session unless valid_email_session?

                render "auth/app/sign/up/emails/edit"
              end

              def create
                return unless load_gate_context!(gate_for_create)

                @user_email = current_registration_email
                return redirect_invalid_session unless @user_email

                result = issue_otp_ceremony!
                return render_otp_ceremony_result(result) unless result.success?

                redirect_to(auth_app_sign_up_check_email_otp_path(ri: params[:ri], pt: signed_pt_param))
              end

              def update
                return unless load_gate_context!(gate_for_update)

                @user_email = current_registration_email
                return redirect_invalid_session unless valid_email_session?

                submitted_code = submitted_pass_code
                return render_code_required if submitted_code.blank?

                result = verify_otp_ceremony!(submitted_code)
                return handle_locked_result if result.status == :locked
                return render_otp_ceremony_result(result) unless result.success?

                @user_email.update!(user_email_status_id: ClientEmailStatus::VERIFIED_WITH_SIGN_UP)
                progress_email_flow!(:update)

                flow_result = advance_sign_up_flow_after_email_otp!
                return render_sign_up_result(flow_result) unless flow_result.success?

                complete_update_and_redirect
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def sign_up_surface = :app

              def sign_up_ticket_class = ClientSignUpFlow

              def sign_up_sequence_session_key = :auth_app_up_sequence_id

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

              def verify_otp_ceremony!(submitted_code)
                return verify_dummy_otp_ceremony!(submitted_code) if dummy_existing_email_flow?

                SignOtpCeremony.verify!(
                  purpose: :sign_up,
                  surface: :app,
                  channel: :email,
                  subject: @sign_up_ticket,
                  destination: @user_email.address,
                  code: submitted_code,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def render_otp_ceremony_result(result)
                if result.status == :rate_limited
                  @user_email.errors.add(:base, t("sign.app.registration.email.create.otp_resend_too_soon"))
                  return render "auth/app/sign/up/emails/edit", status: :too_many_requests
                end

                @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
                render "auth/app/sign/up/emails/edit", status: :unprocessable_content
              end

              def render_code_required
                @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.code_required"))
                render "auth/app/sign/up/emails/edit", status: :unprocessable_content
              end

              def handle_locked_result
                reset_email_flow!
                @user_email.errors.add(:base, t("sign.app.registration.email.update.attempts_exceeded"))
                render "auth/app/sign/up/emails/edit", status: :too_many_requests
              end

              def redirect_invalid_session
                reset_email_flow!
                redirect_to(
                  new_auth_app_sign_up_email_path(ri: params[:ri]),
                  notice: t("sign.app.registration.email.edit.session_expired"),
                )
              end

              def complete_update_and_redirect
                redirect_to(auth_app_sign_up_check_email_birthdate_path(ri: params[:ri], pt: signed_pt_param))
              end

              def advance_sign_up_flow_after_email_otp!
                result = perform_sign_up_event(:verify_contact)
                return unexpected_email_otp_transition(result, :enter_guardrail) unless result.success? &&
                  result.next_event == :enter_guardrail

                result = perform_sign_up_event(:enter_guardrail)
                return unexpected_email_otp_transition(result, :enter_checkpoint) unless result.success? &&
                  result.next_event == :enter_checkpoint

                result = perform_sign_up_event(:enter_checkpoint)
                return unexpected_email_otp_transition(result, :clear_requirement) unless result.success? &&
                  result.next_event == :clear_requirement

                mark_email_otp_requirement_cleared!
                result
              end

              def unexpected_email_otp_transition(result, expected_next_event)
                Rails.logger.warn(
                  JitLogEvent.format(
                    "sign.signup.email.otp.transition_unexpected",
                    status: result.status,
                    next_event: result.next_event,
                    expected_next_event: expected_next_event,
                  ),
                )
                SignUpResult.build(
                  status: :invalid_transition,
                  ticket: @sign_up_ticket,
                  errors: ["unexpected email OTP sign-up transition"],
                )
              end

              def mark_email_otp_requirement_cleared!
                requirements = @sign_up_ticket.completed_requirements.deep_dup
                requirements["otp"] = {
                  "cleared" => true,
                  "cleared_at" => Time.current.iso8601,
                }
                @sign_up_ticket.update!(completed_requirements: requirements)
              end

              def verify_dummy_otp_ceremony!(submitted_code)
                verify_dummy_otp(submitted_code)
                SignOtpCeremony::Result.new(
                  success?: false,
                  status: :invalid_code,
                  record: nil,
                  code: nil,
                  error: :invalid_code,
                )
              end

              def submitted_pass_code
                params.dig("client_email", "pass_code").presence ||
                  params.dig("user_email", "pass_code").presence
              end
            end
          end
        end
      end
    end
  end
end
