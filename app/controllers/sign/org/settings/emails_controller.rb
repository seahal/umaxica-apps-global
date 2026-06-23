# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      class EmailsController < ::Sign::Org::ApplicationController
        include CloudflareTurnstile
        include ::VerificationOperator

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :authorize_emails!, only: :index

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
              edit_sign_org_settings_email_path(@staff_email.public_id, ri: params[:ri]),
              status: :see_other,
            )
          else
            @staff_email.errors.add(:base, t("sign.org.settings.email.update.failure"))
            render(:edit, status: :unprocessable_content)
          end
        end

        def destroy
          @staff_email = current_operator.staff_emails.find_by!(public_id: params(:id))
          authorize!(@staff_email)

          if @staff_email.undeletable?
            redirect_to(
              sign_org_settings_emails_path(ri: params[:ri]),
              alert: t("sign.org.settings.email.destroy.protected"),
            )
            return
          end

          unless AuthMethodGuard.can_remove_email?(current_operator, @staff_email)
            redirect_to(
              sign_org_settings_emails_path(ri: params[:ri]),
              alert: t("sign.org.settings.email.destroy.last_method"),
            )
            return
          end

          @staff_email.destroy!
          redirect_to(
            sign_org_settings_emails_path(ri: params[:ri]),
            notice: t("sign.org.settings.email.destroy.success"),
            status: :see_other,
          )
        end

        private

        def authorize_emails!
          authorize!(OperatorEmail, to: :index?)
        end

        def email_preference_params
          params.fetch(:staff_email, {}).permit(:promotional, :notifiable)
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "settings_email"
        end
      end
    end
  end
end
