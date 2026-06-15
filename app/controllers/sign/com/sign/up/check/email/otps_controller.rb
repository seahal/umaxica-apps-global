# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      module Up
        module Check
          module Email
            class OtpsController < ::Sign::Com::Sign::Up::EmailsController
              include SignUpExplicitStepControllerSupport

              AUTHENTICATION_MODE = :guest
              skip_before_action :enforce_email_flow!

              def show
                return unless load_gate_context!(gate_for_show)

                @user_email = current_registration_email
                return redirect_invalid_session unless valid_email_session?

                render "sign/com/sign/up/emails/edit"
              end

              def create
                return unless load_gate_context!(gate_for_create)

                @user_email = current_registration_email
                return redirect_invalid_session unless @user_email

                result = issue_otp_ceremony!
                return render_otp_ceremony_result(result) unless result.success?

                redirect_to(sign_com_sign_up_check_email_otp_path(ri: params[:ri], pt: signed_pt_param))
              end

              def update
                return unless load_gate_context!(gate_for_update)

                @user_email = current_registration_email
                return redirect_invalid_session unless valid_email_session?
                return render_code_required if params.dig("visitor_email", "pass_code").blank?

                result = verify_otp_ceremony!
                return handle_locked_result if result.status == :locked
                return render_otp_ceremony_result(result) unless result.success?

                @user_email.update!(visitor_email_status_id: VisitorEmailStatus::VERIFIED_WITH_SIGN_UP)
                progress_email_flow!(:update)
                advance_sign_up_flow_after_email_otp!
                redirect_to(
                  sign_com_sign_up_guard_email_path(
                    ri: params[:ri],
                    pt: signed_pt_token(path_target_value),
                  ),
                )
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def sign_up_surface = :com

              def sign_up_ticket_class = VisitorSignUpFlow

              def sign_up_sequence_session_key = :sign_com_up_sequence_id

              def sign_up_family = "email"

              def sign_up_step = :otp

              def issue_otp_ceremony!
                SignOtpCeremony.issue!(
                  purpose: :sign_up,
                  surface: :com,
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
                  surface: :com,
                  channel: :email,
                  subject: @sign_up_ticket,
                  destination: @user_email.address,
                  code: params.dig("visitor_email", "pass_code"),
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def render_otp_ceremony_result(result)
                if result.status == :rate_limited
                  @user_email.errors.add(:base, t("sign.app.registration.email.create.otp_resend_too_soon"))
                  return render "sign/com/sign/up/emails/edit", status: :too_many_requests
                end

                @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
                render "sign/com/sign/up/emails/edit", status: :unprocessable_content
              end

              def redirect_invalid_session
                reset_email_flow!
                @user_email ||= VisitorEmail.new
                @user_email.errors.add(:base, t("sign.app.registration.email.edit.session_expired"))
                render "sign/com/sign/up/emails/edit", status: :unprocessable_content
              end

              def handle_locked_result
                reset_email_flow!
                @user_email.errors.add(:base, t("sign.app.registration.email.update.attempts_exceeded"))
                render "sign/com/sign/up/emails/edit", status: :too_many_requests
              end
            end
          end
        end
      end
    end
  end
end
