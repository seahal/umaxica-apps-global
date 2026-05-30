# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class EmailsController < Sign::App::ApplicationController
        include CloudflareTurnstile

        include ::Verification::Client

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        # Object-level authorization (ActionPolicy): the listing gates actor type; the per-record
        # edit/update/destroy authorize the owned record (find_by! is already owner-scoped, so a
        # non-owner gets 404 before this). Verification/turnstile guards remain in place.
        before_action :authorize_emails!, only: %i(index)

        def index
          @client_emails = current_client.client_emails
        end

        def edit
          @user_email = current_client.client_emails.find_by!(public_id: params(:id))
          authorize!(@user_email)
        end

        def update
          @user_email = current_client.client_emails.find_by!(public_id: params(:id))
          authorize!(@user_email)

          unless cloudflare_turnstile_stealth_validation["success"]
            @user_email.errors.add(:base, t("turnstile_error"))
            flash.now[:alert] = t("turnstile_error")
            render(:edit, status: :unprocessable_content)
            return
          end

          if @user_email.update(email_preference_params)
            redirect_to(
              edit_sign_app_configuration_email_path(@user_email.public_id, ri: params[:ri]),
              notice: t("sign.app.configuration.email.update.success"),
              status: :see_other,
            )
          else
            flash.now[:alert] = t("sign.app.configuration.email.update.failure")
            render(:edit, status: :unprocessable_content)
          end
        end

        def destroy
          @user_email = current_client.client_emails.find_by!(public_id: params(:id))
          authorize!(@user_email)

          if @user_email.undeletable?
            redirect_to(
              sign_app_configuration_emails_path(ri: params[:ri]),
              alert: t("sign.app.configuration.email.destroy.protected"),
            )
            return
          end

          if verified_email?(@user_email) && !AuthMethodGuard.can_remove_email?(current_client, @user_email)
            redirect_to(
              sign_app_configuration_emails_path(ri: params[:ri]),
              alert: t("sign.app.configuration.email.destroy.last_method"),
            )
            return
          end

          @user_email.destroy!
          create_audit_event!(ClientChronicleEvent::EMAIL_REMOVED, subject: @user_email)

          redirect_to(
            sign_app_configuration_emails_path(ri: params[:ri]),
            notice: t("sign.app.configuration.email.destroy.success"),
            status: :see_other,
          )
        end

        private

        def authorize_emails!
          authorize!(ClientEmail, to: :index?)
        end

        def create_audit_event!(event_id, subject:)
          ChronicleRecord.connected_to(role: :writing) do
            ClientChronicleEvent.find_or_create_by!(id: event_id)
            ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
          end

          ClientChronicle.create!(
            actor_type: "Client",
            actor_id: current_client.id,
            event_id: event_id,
            subject_id: subject.id.to_s,
            subject_type: subject.class.name,
            occurred_at: Time.current,
          )
        end

        def verified_email?(email)
          AuthMethodGuard::VERIFIED_EMAIL_STATUSES.include?(email.user_email_status_id)
        end

        def email_preference_params
          permitted_params = params.fetch(:user_email, {}).permit(:promotional, :notifiable)
          return permitted_params unless @user_email.subscription_preferences_locked?

          permitted_params.to_h.symbolize_keys.merge(
            promotional: @user_email.promotional,
            notifiable: @user_email.notifiable,
          )
        end

        def verification_required_action?
          return step_up_bootstrap_active? if action_name == "index"

          %w(edit update destroy).include?(action_name)
        end

        def verification_scope
          "configuration_email"
        end
      end
    end
  end
end
