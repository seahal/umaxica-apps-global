# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      module Telephones
        class RegistrationsController < ApplicationController
          auth_required!

          include Common::Otp
          include ::Verification::User

          TELEPHONE_VERIFICATION_RATE_LIMIT = 5
          TELEPHONE_VERIFICATION_RATE_WINDOW = 60
          before_action :authenticate_customer!

          def new
            @user_telephone = CustomerTelephone.new
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
            customer = current_customer
            return head :unauthorized if customer.blank?

            tel_params = params.expect(user_telephone: [:raw_number, :number])
            number = tel_params[:raw_number] || tel_params[:number]

            unless initiate_customer_telephone_verification(customer, number, auto_accept_confirmations: true)
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

            submitted_code = params.dig(:user_telephone, :pass_code)
            if submitted_code.blank?
              @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
              render :edit, status: :unprocessable_content
              return
            end

            status =
              complete_customer_telephone_verification(@user_telephone.id, submitted_code) do |customer_telephone|
                customer_telephone.customer = current_customer
                customer_telephone.save!
              end

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

          private

          def current_registration_telephone
            CustomerTelephone.find_by(id: session[registration_session_key])
          end

          def valid_registration_session?
            @user_telephone.present? &&
              @user_telephone.customer_id == current_customer.id &&
              !@user_telephone.otp_expired? &&
              @user_telephone.customer_telephone_status_id == CustomerTelephoneStatus::UNVERIFIED
          end

          def registration_session_key
            :configuration_telephone_registration_id
          end

          def reset_registration_session!
            session.delete(registration_session_key)
          end

          def verification_required_action?
            true
          end

          def verification_scope
            "configuration_telephone"
          end

          def initiate_customer_telephone_verification(customer, number, auto_accept_confirmations: false)
            return false if customer.blank?

            check_telephone_verification_rate_limit!

            digest = IdentifierBlindIndex.bidx_for_telephone(number)
            existing_customer_telephone =
              digest.present? ? customer.customer_telephones.find_by(number_digest: digest) : nil

            @user_telephone = existing_customer_telephone || customer.customer_telephones.build(raw_number: number)
            @user_telephone.raw_number = number if existing_customer_telephone
            @user_telephone.customer_telephone_status_id = CustomerTelephoneStatus::UNVERIFIED
            if auto_accept_confirmations
              @user_telephone.confirm_policy = true
              @user_telephone.confirm_using_mfa = true
            end

            if digest.present? && existing_customer_telephone.blank?
              CustomerTelephone.where(
                number_digest: digest,
                customer_id: customer.id,
                customer_telephone_status_id: CustomerTelephoneStatus::UNVERIFIED,
              ).destroy_all
            end

            otp_number = generate_otp_attributes(@user_telephone)
            return false unless @user_telephone.valid?

            @user_telephone.save!
            send_telephone_verification_sms(@user_telephone, otp_number)
            true
          end

          def complete_customer_telephone_verification(id, submitted_code)
            @user_telephone = CustomerTelephone.find_by(id: id)
            if @user_telephone.blank? ||
                @user_telephone.otp_expired? ||
                @user_telephone.customer_telephone_status_id != CustomerTelephoneStatus::UNVERIFIED
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
            @user_telephone.customer_telephone_status_id = CustomerTelephoneStatus::VERIFIED
            yield(@user_telephone) if block_given?
            :success
          end

          def send_telephone_verification_sms(customer_telephone, otp_number)
            message = I18n.t("sign.telephone_verification.sms_message", code: otp_number)
            SmsDeliveryJob.perform_later(
              to: customer_telephone.number,
              message: message,
              subject: message,
            )
          end

          def check_telephone_verification_rate_limit!
            cache_key = "rate-limit:telephone_verification:#{request.remote_ip}"
            count = RateLimit.store.increment(cache_key, 1, expires_in: TELEPHONE_VERIFICATION_RATE_WINDOW.seconds)
            return unless count && count > TELEPHONE_VERIFICATION_RATE_LIMIT

            Rails.event.notify(
              "telephone.verification.rate_limited",
              ip: request.remote_ip,
              retry_after: TELEPHONE_VERIFICATION_RATE_WINDOW,
            )
            raise ActionController::TooManyRequests
          end
        end
      end
    end
  end
end
