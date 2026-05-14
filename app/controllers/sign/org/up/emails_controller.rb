# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Up
      class EmailsController < ApplicationController
        include ::CloudflareTurnstile

        INVITATION_SESSION_KEY = :org_sign_up_invitation_code

        guest_only! message: I18n.t("sign.org.registration.email.already_logged_in")

        def new
          @staff_email = OperatorEmail.new
          session.delete(INVITATION_SESSION_KEY)
        end

        def create
          invitation_code = params.expect(:invitation_code).to_s.downcase.strip

          if invitation_code.blank?
            @staff_email = OperatorEmail.new
            @staff_email.errors.add(:base, I18n.t("sign.org.registration.email.invitation_required"))
            render :new, status: :unprocessable_content
            return
          end

          begin
            ::Org::RegistrationPolicy.validate!(invitation_code: invitation_code)
            session[INVITATION_SESSION_KEY] = invitation_code
          rescue ::Org::RegistrationPolicy::InvitationRequiredError,
                 ::Org::RegistrationPolicy::InvalidInvitationError,
                 ::Org::RegistrationPolicy::InvitationExpiredError,
                 ::Org::RegistrationPolicy::InvitationConsumedError => e
            @staff_email = OperatorEmail.new
            @staff_email.errors.add(:base, e.message)
            render :new, status: :unprocessable_content
            return
          end

          email_params = params.permit(staff_email: %i(raw_address address confirm_policy))[:staff_email]
          email_address = email_params&.[](:raw_address) || email_params&.[](:address)

          unless cloudflare_turnstile_validation["success"]
            @staff_email = OperatorEmail.new(address: email_address)
            @staff_email.errors.add(:base, I18n.t("sign.org.registration.email.turnstile_failed"))
            render :new, status: :unprocessable_content
            return
          end

          redirect_to(new_sign_org_up_email_path(invitation_code: invitation_code))
        end
      end
    end
  end
end
