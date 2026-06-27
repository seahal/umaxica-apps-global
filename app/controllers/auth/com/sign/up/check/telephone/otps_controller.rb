# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module Up
        module Check
          module Telephone
            class OtpsController < ::Auth::Com::Sign::Up::TelephonesController
              include SignUpExplicitStepControllerSupport

              AUTHENTICATION_MODE = :guest

              def show
                if dummy_existing_telephone_flow?
                  @visitor_telephone = VisitorTelephone.new
                  return render "auth/com/sign/up/telephones/edit" if valid_telephone_session?

                  return render_telephone_session_expired
                end

                return unless load_gate_context!(gate_for_show)

                @visitor_telephone = current_registration_telephone
                return render_telephone_session_expired unless valid_telephone_session?

                render "auth/com/sign/up/telephones/edit"
              end

              def create
                if dummy_existing_telephone_flow?
                  return render_otp_resend_too_soon if otp_resend_rate_limited?

                  perform_dummy_otp_generation
                  session[:visitor_telephone_otp_last_sent_at] = Time.current.to_i
                  return redirect_to(sign_com_sign_up_check_telephone_otp_path(ri: params[:ri], pt: signed_pt_param))
                end

                return unless load_gate_context!(gate_for_create)

                @visitor_telephone = current_registration_telephone
                return render_telephone_session_expired unless @visitor_telephone
                return render_otp_resend_too_soon if otp_resend_rate_limited?

                result = issue_otp_ceremony!
                return render_otp_ceremony_result(result) unless result.success?

                registration = (session[:visitor_telephone_registration] || {}).dup
                registration["public_id"] ||= @visitor_telephone.public_id
                registration["expires_at"] = @visitor_telephone.reload.otp_expires_at.to_i
                session[:visitor_telephone_registration] = registration
                session[:visitor_telephone_otp_last_sent_at] = Time.current.to_i
                redirect_to(sign_com_sign_up_check_telephone_otp_path(ri: params[:ri], pt: signed_pt_param))
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def sign_up_surface = :com

              def sign_up_ticket_class = VisitorSignUpFlow

              def sign_up_sequence_session_key = :sign_com_up_sequence_id

              def sign_up_family = "telephone"

              def sign_up_step = :otp

              def issue_otp_ceremony!
                SignOtpCeremony.issue!(
                  purpose: :sign_up,
                  surface: :com,
                  channel: :telephone,
                  subject: @sign_up_ticket,
                  destination: @visitor_telephone.number,
                  session_nonce: @sign_up_ticket.public_id,
                  request_context: request,
                )
              end

              def render_otp_ceremony_result(result)
                if result.status == :rate_limited
                  @visitor_telephone.errors.add(:base, t("sign.app.registration.email.create.otp_resend_too_soon"))
                  return render "auth/com/sign/up/telephones/edit", status: :too_many_requests
                end

                @visitor_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
                render "auth/com/sign/up/telephones/edit", status: :unprocessable_content
              end

              def render_telephone_session_expired
                @visitor_telephone ||= VisitorTelephone.new
                @visitor_telephone.errors.add(:base, t("sign.com.registration.telephone.edit.session_expired"))
                render "auth/com/sign/up/telephones/edit", status: :unprocessable_content
              end

              def otp_resend_rate_limited?
                last_sent_at = session[:visitor_telephone_otp_last_sent_at]
                return false if last_sent_at.blank?

                last_sent_at.to_i > CommonOtpPolicy::SEND_COOLDOWN.ago.to_i
              end
            end
          end
        end
      end
    end
  end
end
