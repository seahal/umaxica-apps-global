# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      module Check
        module Telephone
          class OtpsController < Sign::Com::Up::TelephonesController
            include SignUpExplicitStepControllerSupport

            AUTHENTICATION_MODE = :guest

            def show
              return unless load_gate_context!(gate_for_show)

              @visitor_telephone = current_registration_telephone
              return render_telephone_session_expired unless valid_telephone_session?

              render "sign/com/up/telephones/edit"
            end

            def create
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
              redirect_to(sign_com_up_check_telephone_otp_path(ri: params[:ri], pt: signed_pt_param))
            end

            def update
              return unless load_gate_context!(gate_for_update)

              @visitor_telephone = current_registration_telephone
              return render_telephone_session_expired unless @visitor_telephone
              unless valid_registration_session?(session[:visitor_telephone_registration])
                return render_telephone_session_expired
              end

              submitted_code = params.dig("visitor_telephone", "pass_code")
              if submitted_code.blank?
                @visitor_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
                render "sign/com/up/telephones/edit", status: :unprocessable_content
                return
              end

              result = verify_otp_ceremony!
              if result.status == :locked
                session[:visitor_telephone_registration] = nil
                @visitor_telephone.errors.add(:base, t("sign.app.registration.telephone.update.attempts_exceeded"))
                render "sign/com/up/telephones/edit", status: :too_many_requests
                return
              end
              return render_otp_ceremony_result(result) unless result.success?

              verify_telephone_ownership!
              advance_sign_up_flow_after_telephone_otp!
              redirect_to(sign_com_up_guard_telephone_path(ri: params[:ri], pt: signed_pt_param))
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

            def verify_otp_ceremony!
              SignOtpCeremony.verify!(
                purpose: :sign_up,
                surface: :com,
                channel: :telephone,
                subject: @sign_up_ticket,
                destination: @visitor_telephone.number,
                code: params.dig("visitor_telephone", "pass_code"),
                session_nonce: @sign_up_ticket.public_id,
                request_context: request,
              )
            end

            def render_otp_ceremony_result(result)
              if result.status == :rate_limited
                @visitor_telephone.errors.add(:base, t("sign.app.registration.email.create.otp_resend_too_soon"))
                return render "sign/com/up/telephones/edit", status: :too_many_requests
              end

              @visitor_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
              render "sign/com/up/telephones/edit", status: :unprocessable_content
            end

            def render_telephone_session_expired
              @visitor_telephone ||= VisitorTelephone.new
              @visitor_telephone.errors.add(:base, t("sign.com.registration.telephone.edit.session_expired"))
              render "sign/com/up/telephones/edit", status: :unprocessable_content
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
