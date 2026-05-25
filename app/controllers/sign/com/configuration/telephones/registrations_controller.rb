# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      module Telephones
        class RegistrationsController < PrivateController
          include CloudflareTurnstile
          include Common::Otp
          include ::Verification::Visitor

          TELEPHONE_VERIFICATION_RATE_LIMIT = 5
          TELEPHONE_VERIFICATION_RATE_WINDOW = 60
          before_action :authenticate_visitor!

          def new
            @user_telephone = VisitorTelephone.new
            reset_registration_session!
          end

          def edit
            @user_telephone = current_registration_telephone
            return if valid_registration_session?

            reset_registration_session!
            redirect_to(
              new_sign_com_configuration_telephones_registration_path(ri: params[:ri]),
              notice: t("sign.app.registration.telephone.edit.session_expired"),
            )
          end

          def create
            visitor = current_visitor
            return head :unauthorized if visitor.blank?

            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone = VisitorTelephone.new
              @user_telephone.errors.add(:base, t("turnstile_error"))
              flash.now[:alert] = t("turnstile_error")
              render(:new, status: :unprocessable_content)
              return
            end

            tel_params = params(user_telephone: [:raw_number, :number])
            number = tel_params[:raw_number] || tel_params[:number]

            unless initiate_visitor_telephone_verification(visitor, number, auto_accept_confirmations: true)
              render :new, status: :unprocessable_content
              return
            end

            session[registration_session_key] = @user_telephone.id
            redirect_to(
              edit_sign_com_configuration_telephones_registration_path(ri: params[:ri]),
              notice: t("sign.app.registration.telephone.create.verification_code_sent"),
            )
          end

          def update
            @user_telephone = current_registration_telephone

            unless valid_registration_session?
              reset_registration_session!
              redirect_to(
                new_sign_com_configuration_telephones_registration_path(ri: params[:ri]),
                notice: t("sign.app.registration.telephone.edit.session_expired"),
              )
              return
            end

            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone.errors.add(:base, t("turnstile_error"))
              flash.now[:alert] = t("turnstile_error")
              render(:edit, status: :unprocessable_content)
              return
            end

            submitted_code = params.dig(:user_telephone, :pass_code)
            if submitted_code.blank?
              @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
              render :edit, status: :unprocessable_content
              return
            end

            status =
              complete_visitor_telephone_verification(@user_telephone.id, submitted_code) do |visitor_telephone|
                visitor_telephone.visitor = current_visitor
                visitor_telephone.save!
              end

            handle_registration_update_status(status)
          end

          private

          def handle_registration_update_status(status)
            case status
            when :success
              reset_registration_session!
              redirect_to(
                sign_com_configuration_telephones_path(ri: params[:ri]),
                notice: t("sign.app.registration.telephone.update.success"),
              )
            when :session_expired
              reset_registration_session!
              redirect_to(
                new_sign_com_configuration_telephones_registration_path(ri: params[:ri]),
                notice: t("sign.app.registration.telephone.edit.session_expired"),
              )
            when :locked
              reset_registration_session!
              redirect_to(
                new_sign_com_configuration_telephones_registration_path(ri: params[:ri]),
                alert: t("sign.app.registration.telephone.update.attempts_exceeded"),
              )
            else
              render :edit, status: :unprocessable_content
            end
          end

          def current_registration_telephone
            VisitorTelephone.find_by(id: session[registration_session_key])
          end

          def valid_registration_session?
            @user_telephone.present? &&
              @user_telephone.visitor_id == current_visitor.id &&
              !@user_telephone.otp_expired? &&
              @user_telephone.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED
          end

          def registration_session_key
            :configuration_telephone_registration_id
          end

          def reset_registration_session!
            session.delete(registration_session_key)
          end

          def verification_required_action?
            current_visitor&.verified_telephone?
          end

          def verification_scope
            "configuration_telephone"
          end

          def initiate_visitor_telephone_verification(visitor, number, auto_accept_confirmations: false)
            return false if visitor.blank?

            check_telephone_verification_rate_limit!

            digest = IdentifierBlindIndex.bidx_for_telephone(number)
            existing_visitor_telephone =
              digest.present? ? visitor.visitor_telephones.find_by(number_digest: digest) : nil

            @user_telephone = existing_visitor_telephone || visitor.visitor_telephones.build(raw_number: number)
            @user_telephone.raw_number = number if existing_visitor_telephone
            @user_telephone.visitor_telephone_status_id = VisitorTelephoneStatus::UNVERIFIED
            if auto_accept_confirmations
              @user_telephone.confirm_policy = true
              @user_telephone.confirm_using_mfa = true
            end

            if digest.present? && existing_visitor_telephone.blank?
              VisitorTelephone.where(
                number_digest: digest,
                visitor_id: visitor.id,
                visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
              ).destroy_all
            end

            otp_number = generate_otp_attributes(@user_telephone)
            return false unless @user_telephone.valid?

            @user_telephone.save!
            send_telephone_verification_sms(@user_telephone, otp_number)
            true
          end

          def complete_visitor_telephone_verification(id, submitted_code)
            @user_telephone = VisitorTelephone.find_by(id: id)
            if @user_telephone.blank? ||
                @user_telephone.otp_expired? ||
                @user_telephone.visitor_telephone_status_id != VisitorTelephoneStatus::UNVERIFIED
              return :session_expired
            end

            result = verify_otp_code(@user_telephone, submitted_code)

            unless result[:success]
              increment_otp_attempts!(@user_telephone)
              if @user_telephone.locked?
                @user_telephone.destroy!
                return :locked
              end

              @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
              return :invalid_code
            end

            clear_otp(@user_telephone)
            @user_telephone.visitor_telephone_status_id = VisitorTelephoneStatus::VERIFIED
            yield(@user_telephone) if block_given?
            :success
          end

          def send_telephone_verification_sms(visitor_telephone, otp_number)
            message = I18n.t("sign.telephone_verification.sms_message", code: otp_number)
            Outbound::Sms.deliver_later(
              to: visitor_telephone.number,
              title: message,
              body: message,
            )
          end

          def check_telephone_verification_rate_limit!
            cache_key = "rate-limit:telephone_verification:#{request.remote_ip}"
            count = RateLimit.store.increment(cache_key, 1, expires_in: TELEPHONE_VERIFICATION_RATE_WINDOW.seconds)
            return unless count && count > TELEPHONE_VERIFICATION_RATE_LIMIT

            Rails.logger.info(
              LogEvent.format(
                "telephone.verification.rate_limited",
                ip: request.remote_ip,
                retry_after: TELEPHONE_VERIFICATION_RATE_WINDOW,
              ),
            )
            raise ActionController::TooManyRequests
          end
        end
      end
    end
  end
end
