# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class EmailsController < BaseController
        include CloudflareTurnstile
        include VerificationClient

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_emails!, only: :index

        def index
          @client_emails = current_client.client_emails
          render "auth/app/settings/emails/index"
        end

        def edit
          @user_email = current_client.client_emails.find_by!(public_id: params.expect(:id))
          authorize!(@user_email)
          render "auth/app/settings/emails/edit"
        end

        def update
          @user_email = current_client.client_emails.find_by!(public_id: params.expect(:id))
          authorize!(@user_email)
          unless cloudflare_turnstile_stealth_validation["success"]
            @user_email.errors.add(:base, t("turnstile_error"))
            return render("auth/app/settings/emails/edit", status: :unprocessable_content)
          end
          if @user_email.update(email_preference_params)
            redirect_to(edit_base_app_identity_email_path(@user_email.public_id, ri: params[:ri]), status: :see_other)
          else
            @user_email.errors.add(:base, t("sign.app.settings.email.update.failure"))
            render("auth/app/settings/emails/edit", status: :unprocessable_content)
          end
        end

        def destroy
          @user_email = current_client.client_emails.find_by!(public_id: params.expect(:id))
          authorize!(@user_email)
          if @user_email.undeletable? || (verified_email?(@user_email) && !AuthMethodGuard.can_remove_email?(
            current_client, @user_email,
          ))
            return redirect_to(base_app_identity_emails_path(ri: params[:ri]), status: :see_other)
          end

          @user_email.destroy!
          create_audit_event!(ClientChronicleEvent::EMAIL_REMOVED, subject: @user_email)
          redirect_to(base_app_identity_emails_path(ri: params[:ri]), status: :see_other)
        end

        private

        def authorize_emails! = authorize!(ClientEmail, to: :index?)

        def verified_email?(email) = AuthMethodGuard::VERIFIED_EMAIL_STATUSES.include?(email.user_email_status_id)

        def email_preference_params
          permitted_params = params.fetch(:user_email, {}).permit(:promotional, :notifiable)
          return permitted_params unless @user_email.subscription_preferences_locked?

          permitted_params.to_h.symbolize_keys.merge(
            promotional: @user_email.promotional,
            notifiable: @user_email.notifiable,
          )
        end

        def create_audit_event!(event_id, subject:)
          ClientChronicle.create!(
            actor_type: "Client", actor_id: current_client.id, event_id: event_id,
            subject_id: subject.id.to_s, subject_type: subject.class.name, occurred_at: Time.current,
          )
        end
      end
    end
  end
end
