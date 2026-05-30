# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class EmailsController < Sign::Org::ApplicationController
        include CloudflareTurnstile

        include ::Verification::Operator

        AUTHENTICATION_MODE = :private

        VERIFIED_EMAIL_STATUSES = [
          OperatorEmailStatus::ACTIVE,
          OperatorEmailStatus::VERIFIED,
        ].freeze

        before_action :authenticate_operator!
        # Object-level authorization (ActionPolicy): the listing gates actor type; the per-record
        # edit/update/destroy authorize the owned record (find_by! is already owner-scoped, so a
        # non-owner gets 404 before this). Verification/turnstile guards remain in place.
        before_action :authorize_emails!, only: %i(index)

        def index
          @staff_emails = current_operator.staff_emails.order(created_at: :asc)
        end

        def edit
          @staff_email = current_operator.staff_emails.find_by!(public_id: params(:id))
          authorize!(@staff_email)
        end

        def update
          @staff_email = current_operator.staff_emails.find_by!(public_id: params(:id))
          authorize!(@staff_email)

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
          @staff_email = current_operator.staff_emails.find_by!(public_id: params(:id))
          authorize!(@staff_email)

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

        def authorize_emails!
          authorize!(OperatorEmail, to: :index?)
        end

        def removable_email?(staff_email)
          AuthMethodGuard.can_remove_email?(current_operator, staff_email)
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
