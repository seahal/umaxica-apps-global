# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      module Telephones
        class RegistrationsController < Sign::Org::ApplicationController
          include CloudflareTurnstile

          include Sign::OperatorTelephoneRegistrable

          include ::Verification::Operator

          AUTHENTICATION_MODE = :private

          before_action :authenticate_operator!

          def new
            @staff_telephone = OperatorTelephone.new
            reset_registration_session!
          end

          def edit
            @staff_telephone = current_registration_telephone
            return if valid_registration_session?

            reset_registration_session!
            redirect_to(
              new_sign_org_configuration_telephones_registration_path,
              notice: t("sign.org.registration.telephone.edit.session_expired"),
            )
          end

          def create
            unless cloudflare_turnstile_stealth_validation["success"]
              @staff_telephone = OperatorTelephone.new
              @staff_telephone.errors.add(:base, t("turnstile_error"))
              flash.now[:alert] = t("turnstile_error")
              render(:new, status: :unprocessable_content)
              return
            end

            tel_params = params(staff_telephone: [:raw_number, :number])
            number = tel_params[:raw_number] || tel_params[:number]

            unless initiate_staff_telephone_verification(current_operator, number)
              render :new, status: :unprocessable_content
              return
            end

            session[registration_session_key] = @staff_telephone.id
            redirect_to(
              edit_sign_org_configuration_telephones_registration_path,
              notice: t("sign.org.registration.telephone.create.verification_code_sent"),
            )
          end

          def update
            @staff_telephone = current_registration_telephone
            unless valid_registration_session?
              reset_registration_session!
              redirect_to(
                new_sign_org_configuration_telephones_registration_path,
                notice: t("sign.org.registration.telephone.edit.session_expired"),
              )
              return
            end

            unless cloudflare_turnstile_stealth_validation["success"]
              @staff_telephone.errors.add(:base, t("turnstile_error"))
              flash.now[:alert] = t("turnstile_error")
              render(:edit, status: :unprocessable_content)
              return
            end

            submitted_code = params.dig(:staff_telephone, :pass_code)
            if submitted_code.blank?
              @staff_telephone.errors.add(:pass_code, t("sign.org.registration.telephone.update.code_required"))
              render :edit, status: :unprocessable_content
              return
            end

            result =
              complete_staff_telephone_verification(@staff_telephone.id, submitted_code) do |staff_telephone|
                staff_telephone.staff = current_operator
                staff_telephone.save!
              end

            handle_registration_update_result(result)
          end

          private

          def handle_registration_update_result(result)
            case result
            when :success
              reset_registration_session!
              redirect_to(
                sign_org_configuration_telephones_path,
                notice: t("sign.org.registration.telephone.update.success"),
              )
            when :session_expired
              reset_registration_session!
              redirect_to(
                new_sign_org_configuration_telephones_registration_path,
                notice: t("sign.org.registration.telephone.edit.session_expired"),
              )
            when :locked
              reset_registration_session!
              redirect_to(
                new_sign_org_configuration_telephones_registration_path,
                alert: t("sign.org.registration.telephone.update.attempts_exceeded"),
              )
            else
              render :edit, status: :unprocessable_content
            end
          end

          def current_registration_telephone
            current_operator.staff_telephones.find_by(id: session[registration_session_key])
          end

          def valid_registration_session?
            @staff_telephone.present? &&
              !@staff_telephone.otp_expired? &&
              @staff_telephone.staff_telephone_status_id == OperatorTelephoneStatus::UNVERIFIED
          end

          def registration_session_key
            :staff_telephone_registration_id
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
        end
      end
    end
  end
end
