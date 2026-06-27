# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Telephone
            class OtpsController < ::Auth::App::Sign::Up::TelephonesController
              include SignUpExplicitStepControllerSupport

              AUTHENTICATION_MODE = :guest

              def show
                if dummy_existing_telephone_flow?
                  @user_telephone = ClientTelephone.new
                  return render "auth/app/sign/up/telephones/edit" if valid_telephone_session?

                  return redirect_telephone_session_expired
                end

                return unless load_gate_context!(gate_for_show)

                @user_telephone = current_registration_telephone
                return redirect_telephone_session_expired unless valid_telephone_session?

                render "auth/app/sign/up/telephones/edit"
              end

              def create
                if dummy_existing_telephone_flow?
                  return render_otp_resend_too_soon if otp_resend_rate_limited?

                  perform_dummy_otp_generation
                  session[:user_telephone_otp_last_sent_at] = Time.current.to_i
                  return redirect_to(auth_app_sign_up_check_telephone_otp_path(ri: params[:ri], pt: signed_pt_param))
                end

                return unless load_gate_context!(gate_for_create)

                @user_telephone = current_registration_telephone
                return redirect_telephone_session_expired unless @user_telephone
                return render_otp_resend_too_soon if otp_resend_rate_limited?

                result = issue_otp_ceremony!
                return render_otp_ceremony_result(result) unless result.success?

                registration = (session[:user_telephone_registration] || {}).dup
                registration["public_id"] ||= @user_telephone.public_id
                registration["expires_at"] = @user_telephone.reload.otp_expires_at.to_i
                session[:user_telephone_registration] = registration
                session[:user_telephone_otp_last_sent_at] = Time.current.to_i
                redirect_to(auth_app_sign_up_check_telephone_otp_path(ri: params[:ri], pt: signed_pt_param))
              end

              def update
                if dummy_existing_telephone_flow?
                  @user_telephone = ClientTelephone.new
                  submitted_code = submitted_pass_code
                  return render_code_required if submitted_code.blank?

                  result = verify_otp_ceremony!(submitted_code)
                  return render_otp_ceremony_result(result) unless result.success?
                end

                return unless load_gate_context!(gate_for_update)

                @user_telephone = current_registration_telephone
                return redirect_telephone_session_expired unless valid_telephone_session?

                submitted_code = submitted_pass_code
                return render_code_required if submitted_code.blank?

                result = verify_otp_ceremony!(submitted_code)
                return handle_locked_result if result.status == :locked
                return render_otp_ceremony_result(result) unless result.success?

                verify_telephone_ownership!

                flow_result = advance_sign_up_flow_after_telephone_otp!
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

              def sign_up_family = "telephone"

              def sign_up_step = :otp

              def issue_otp_ceremony!
                SignOtpCeremony.issue!(
                  purpose: :sign_up,
                  surface: :app,
                  channel: :telephone,
                  subject: @sign_up_ticket,
                  destination: @user_telephone.number,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def verify_otp_ceremony!(submitted_code)
                return verify_dummy_otp_ceremony!(submitted_code) if dummy_existing_telephone_flow?

                SignOtpCeremony.verify!(
                  purpose: :sign_up,
                  surface: :app,
                  channel: :telephone,
                  subject: @sign_up_ticket,
                  destination: @user_telephone.number,
                  code: submitted_code,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def verify_telephone_ownership!
                registration = (session[:user_telephone_registration] || {}).dup
                registration["public_id"] ||= @user_telephone.public_id
                registration["otp_verified"] = true
                session[:user_telephone_registration] = registration
              end

              def render_otp_ceremony_result(result)
                if result.status == :rate_limited
                  @user_telephone.errors.add(:base, t("sign.app.registration.email.create.otp_resend_too_soon"))
                  return render "auth/app/sign/up/telephones/edit", status: :too_many_requests
                end

                @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
                render "auth/app/sign/up/telephones/edit", status: :unprocessable_content
              end

              def render_code_required
                @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
                render "auth/app/sign/up/telephones/edit", status: :unprocessable_content
              end

              def handle_locked_result
                reset_telephone_flow!
                @user_telephone.errors.add(:base, t("sign.app.registration.telephone.update.attempts_exceeded"))
                render "auth/app/sign/up/telephones/edit", status: :too_many_requests
              end

              def complete_update_and_redirect
                redirect_to(auth_app_sign_up_guard_telephone_path(ri: params[:ri], pt: signed_pt_param))
              end

              def advance_sign_up_flow_after_telephone_otp!
                result = perform_sign_up_event(:verify_contact)
                return unexpected_telephone_otp_transition(result, :enter_guardrail) unless result.success? &&
                  result.next_event == :enter_guardrail

                result = perform_sign_up_event(:enter_guardrail)
                return unexpected_telephone_otp_transition(result, :enter_checkpoint) unless result.success? &&
                  result.next_event == :enter_checkpoint

                result = perform_sign_up_event(:enter_checkpoint)
                return unexpected_telephone_otp_transition(result, :clear_requirement) unless result.success? &&
                  result.next_event == :clear_requirement

                mark_telephone_otp_requirement_cleared!
                result
              end

              def unexpected_telephone_otp_transition(result, expected_next_event)
                Rails.logger.warn(
                  JitLogEvent.format(
                    "sign.signup.telephone.otp.transition_unexpected",
                    status: result.status,
                    next_event: result.next_event,
                    expected_next_event: expected_next_event,
                  ),
                )
                SignUpResult.build(
                  status: :invalid_transition,
                  ticket: @sign_up_ticket,
                  errors: ["unexpected telephone OTP sign-up transition"],
                )
              end

              def mark_telephone_otp_requirement_cleared!
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
                params.dig("client_telephone", "pass_code").presence ||
                  params.dig("user_telephone", "pass_code").presence
              end

              def reset_telephone_flow!
                session[:user_telephone_registration] = nil
                sign_up_flow_locator.clear!
              end

              def redirect_telephone_session_expired
                reset_telephone_flow!
                redirect_to(
                  new_auth_app_sign_up_telephone_path(ri: params[:ri]),
                  notice: t("sign.app.registration.telephone.edit.session_expired"),
                )
              end
            end
          end
        end
      end
    end
  end
end
