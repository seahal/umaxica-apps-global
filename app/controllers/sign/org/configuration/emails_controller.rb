# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class EmailsController < ApplicationController
        auth_required!

        include CloudflareTurnstile
        include ::Verification::Operator

        VERIFIED_EMAIL_STATUSES = [
          OperatorEmailStatus::ACTIVE,
          OperatorEmailStatus::VERIFIED,
        ].freeze

        before_action :authenticate_operator!

        def index
          @staff_emails = current_operator.staff_emails.order(created_at: :asc)
        end

        def edit
          @staff_email = current_operator.staff_emails.find_by!(public_id: params.expect(:id))
        end

        def update
          @staff_email = current_operator.staff_emails.find_by!(public_id: params.expect(:id))

          unless cloudflare_turnstile_stealth_validation["success"]
            @staff_email.errors.add(:base, t("turnstile_error"))
            flash.now[:alert] = t("turnstile_error")
            render(:edit, status: :unprocessable_content)
            return
          end

          if @staff_email.update(email_preference_params)
            redirect_to(
              edit_sign_org_configuration_email_path(@staff_email.public_id, ri: params[:ri]),
              notice: t("sign.org.configuration.email.update.success"),
              status: :see_other,
            )
          else
            flash.now[:alert] = t("sign.org.configuration.email.update.failure")
            render(:edit, status: :unprocessable_content)
          end
        end

        def destroy
          @staff_email = current_operator.staff_emails.find_by!(public_id: params.expect(:id))

          if @staff_email.undeletable?
            redirect_to(
              sign_org_configuration_emails_path,
              alert: t("sign.org.configuration.email.destroy.protected"),
            )
            return
          end

          unless removable_email?(@staff_email)
            redirect_to(
              sign_org_configuration_emails_path,
              alert: t("sign.org.configuration.email.destroy.last_method"),
            )
            return
          end

          @staff_email.destroy!
          redirect_to(
            sign_org_configuration_emails_path,
            notice: t("sign.org.configuration.email.destroy.success"),
            status: :see_other,
          )
        end

        private

        def removable_email?(staff_email)
          current_operator.staff_emails
            .where(staff_identity_email_status_id: VERIFIED_EMAIL_STATUSES)
            .where.not(id: staff_email.id)
            .exists?
        end

        def email_preference_params
          params.fetch(:staff_email, {}).permit(:promotional, :notifiable)
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "configuration_email"
        end
      end
    end
  end
end
