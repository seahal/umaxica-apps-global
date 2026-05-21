# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      module Emails
        class RegistrationsController < PrivateController
          include ::CloudflareTurnstile
          include Common::Otp
          include Common::Redirect
          include ::Verification::Visitor

          before_action :authenticate_visitor!
          before_action :preserve_email_registration_redirect_parameter, only: %i(new create edit update)
          before_action only: %i(new create) do
            require_step_up_unless_bootstrap!(scope: verification_scope)
          end
          before_action only: %i(edit update) do
            require_step_up!(scope: verification_scope)
          end

          def new
            @user_email = VisitorEmail.new
          end

          def edit
            @user_email = current_registration_email
            @verification_token = params[:token]
            return if valid_registration_email_session?

            reset_email_registration_flow!
            redirect_to(new_registration_path_with_notice)
          end

          def create
            email_params = params(visitor_email: %i(raw_address address notifiable))
            email_address = email_params[:raw_address] || email_params[:address]

            unless initiate_visitor_email_verification!(
              email_address,
              email_preferences: email_params.slice(:notifiable),
            )
              render :new, status: :unprocessable_content
              return
            end

            session[registration_email_session_key] = @user_email.public_id
            redirect_params = build_notice_params(
              t("sign.app.registration.email.create.verification_code_sent"),
              email_registration_rt_session_key,
            )
            flash[:notice] = redirect_params.delete(:notice)
            sanitize_redirect_params!(redirect_params)
            redirect_to(edit_sign_com_configuration_emails_registration_path(redirect_params))
          end

          def update
            @user_email = current_registration_email

            unless valid_registration_email_session?
              reset_email_registration_flow!
              redirect_to(new_registration_path_with_notice)
              return
            end

            submitted_code = params.dig(:visitor_email, :pass_code)
            if submitted_code.blank?
              @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.code_required"))
              render :edit, status: :unprocessable_content
              return
            end

            result = verify_otp_code(@user_email, submitted_code)
            unless result[:success]
              increment_otp_attempts!(@user_email)
              if @user_email.locked?
                @user_email.destroy!
                reset_email_registration_flow!
                flash[:alert] = t("sign.app.registration.email.update.attempts_exceeded")
                redirect_to(new_sign_com_configuration_emails_registration_path(ri: params[:ri]))
                return
              end

              @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
              render :edit, status: :unprocessable_content
              return
            end

            clear_otp(@user_email)
            @user_email.update!(visitor_email_status_id: VisitorEmailStatus::VERIFIED)
            session.delete(registration_email_session_key)
            redirect_to(
              email_registration_return_path(sign_com_configuration_emails_path(ri: params[:ri])),
              notice: t("sign.app.registration.email.update.success"),
            )
          end

          private

          def initiate_visitor_email_verification!(email_address, email_preferences: {})
            turnstile_result = cloudflare_turnstile_stealth_validation
            unless turnstile_result["success"]
              @user_email = VisitorEmail.new(raw_address: email_address, confirm_policy: "1")
              @user_email.errors.add(:base, t("sign.app.registration.email.create.turnstile_validation_failed"))
              return false
            end

            @user_email = current_visitor.visitor_emails.build(
              { raw_address: email_address, confirm_policy: "1" }.merge(email_preferences),
            )
            @user_email.visitor_email_status_id = VisitorEmailStatus::UNVERIFIED
            otp_code = generate_otp_attributes(@user_email)
            return false unless @user_email.valid?

            remove_existing_unverified_visitor_emails!
            @user_email.otp_last_sent_at = Time.current
            @user_email.save!
            Email::Com::OtpMailer.with(
              encrypted_hotp_token: Outbound::SensitivePayload.encrypt_email_otp(otp_code),
              email_address: @user_email.address,
              verification_token: nil,
              public_id: @user_email.public_id,
            ).create.deliver_later

            true
          rescue ActiveRecord::RecordInvalid => e
            @user_email = e.record if e.record.is_a?(VisitorEmail)
            false
          end

          def remove_existing_unverified_visitor_emails!
            return if @user_email.address_digest.blank?

            current_visitor
              .visitor_emails
              .where(
                address_digest: @user_email.address_digest,
                visitor_email_status_id: VisitorEmailStatus::UNVERIFIED,
              )
              .where.not(id: @user_email.id)
              .find_each(&:destroy!)
          end

          def current_registration_email
            current_visitor.visitor_emails.find_by(public_id: session[registration_email_session_key])
          end

          def valid_registration_email_session?
            @user_email.present? &&
              !@user_email.otp_expired? &&
              @user_email.visitor_email_status_id == VisitorEmailStatus::UNVERIFIED
          end

          def registration_email_session_key
            :com_configuration_email_registration_public_id
          end

          def reset_email_registration_flow!
            session.delete(registration_email_session_key)
          end

          def new_registration_path_with_notice
            redirect_params = build_notice_params(
              t("sign.app.registration.email.edit.session_expired"),
              email_registration_rt_session_key,
            )
            flash[:notice] = redirect_params.delete(:notice)
            sanitize_redirect_params!(redirect_params)
            new_sign_com_configuration_emails_registration_path(redirect_params)
          end

          def email_registration_return_path(default_path)
            encoded = retrieve_redirect_parameter(email_registration_rt_session_key)
            return default_path if encoded.blank?

            decoded = Base64.urlsafe_decode64(encoded)
            safe_internal_path(decoded).presence || default_path
          rescue ArgumentError, URI::InvalidURIError
            default_path
          end

          def preserve_email_registration_redirect_parameter
            preserve_redirect_parameter(email_registration_rt_session_key)
          end

          def email_registration_rt_session_key
            :com_configuration_email_registration_rt
          end

          def sanitize_redirect_params!(redirect_params)
            return if redirect_params[:rt].blank?

            redirect_params[:rt] = sanitize_encoded_redirect(redirect_params[:rt])
            redirect_params.delete(:rt) if redirect_params[:rt].blank?
          end

          def sanitize_encoded_redirect(encoded_url)
            return if encoded_url.blank?

            decoded_url = Base64.urlsafe_decode64(encoded_url)
            safe_path = safe_internal_path(decoded_url)

            Base64.urlsafe_encode64(safe_path) if safe_path
          rescue ArgumentError, URI::InvalidURIError
            nil
          end

          def verification_required_action?
            step_up_bootstrap_active?
          end

          def verification_scope
            "configuration_email"
          end
        end
      end
    end
  end
end
