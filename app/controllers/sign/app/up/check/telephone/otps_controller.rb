# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      module Check
        module Telephone
          class OtpsController < Sign::App::Up::TelephonesController
            include SignUpExplicitStepControllerSupport

            AUTHENTICATION_MODE = :guest

            def show
              return unless load_gate_context!(gate_for_show)

              @user_telephone = current_registration_telephone
              return render_telephone_session_expired unless valid_telephone_session?

              render "sign/app/up/telephones/edit"
            end

            def create
              return unless load_gate_context!(gate_for_create)

              @user_telephone = current_registration_telephone
              return render_telephone_session_expired unless @user_telephone
              return render_otp_resend_too_soon if otp_resend_rate_limited?

              result = issue_otp_ceremony!
              return render_otp_ceremony_result(result) unless result.success?

              registration = (session[:user_telephone_registration] || {}).dup
              registration["public_id"] ||= @user_telephone.public_id
              registration["expires_at"] = @user_telephone.reload.otp_expires_at.to_i
              session[:user_telephone_registration] = registration
              session[:user_telephone_otp_last_sent_at] = Time.current.to_i
              redirect_to(sign_app_up_check_telephone_otp_path(ri: params[:ri], pt: signed_pt_param))
            end

            def update
              return unless load_gate_context!(gate_for_update)

              @user_telephone = current_registration_telephone
              return render_telephone_session_expired unless @user_telephone
              unless valid_registration_session?(session[:user_telephone_registration])
                return render_telephone_session_expired
              end

              submitted_code = params.dig("user_telephone", "pass_code")
              if submitted_code.blank?
                @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
                render "sign/app/up/telephones/edit", status: :unprocessable_content
                return
              end

              result = verify_otp_ceremony!
              if result.status == :locked
                session[:user_telephone_registration] = nil
                @user_telephone.errors.add(:base, t("sign.app.registration.telephone.update.attempts_exceeded"))
                render "sign/app/up/telephones/edit", status: :too_many_requests
                return
              end
              return render_otp_ceremony_result(result) unless result.success?

              verify_telephone_ownership!
              advance_sign_up_flow_after_telephone_otp!
              redirect_to(sign_app_up_guard_telephone_path(ri: params[:ri], pt: signed_pt_param))
            end

            def destroy
              cancel_from_explicit_step
            end

            private

            def sign_up_surface = :app

            def sign_up_ticket_class = ClientSignUpFlow

            def sign_up_sequence_session_key = :sign_app_up_sequence_id

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

            def verify_otp_ceremony!
              SignOtpCeremony.verify!(
                purpose: :sign_up,
                surface: :app,
                channel: :telephone,
                subject: @sign_up_ticket,
                destination: @user_telephone.number,
                code: params.dig("user_telephone", "pass_code"),
                session_nonce: @sign_up_ticket.public_id,
                request_context: request,
              )
            end

            def render_otp_ceremony_result(result)
              if result.status == :rate_limited
                @user_telephone.errors.add(:base, t("sign.app.registration.email.create.otp_resend_too_soon"))
                return render "sign/app/up/telephones/edit", status: :too_many_requests
              end

              @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
              render "sign/app/up/telephones/edit", status: :unprocessable_content
            end
          end
        end
      end
    end
  end
end
