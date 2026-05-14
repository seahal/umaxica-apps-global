# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class EmailsController < ApplicationController
        auth_required!

        include CloudflareTurnstile
        include ::Verification::User

        before_action :authenticate_visitor!

        def index
          @user_emails = current_visitor.visitor_emails
        end

        def edit
          @user_email = current_visitor.visitor_emails.find_by!(public_id: params.expect(:id))
        end

        def update
          @user_email = current_visitor.visitor_emails.find_by!(public_id: params.expect(:id))

          unless cloudflare_turnstile_stealth_validation["success"]
            @user_email.errors.add(:base, t("turnstile_error"))
            flash.now[:alert] = t("turnstile_error")
            render(:edit, status: :unprocessable_content)
            return
          end

          if @user_email.update(email_preference_params)
            redirect_to(
              edit_sign_com_configuration_email_path(@user_email.public_id, ri: params[:ri]),
              notice: t("sign.com.configuration.email.update.success"),
              status: :see_other,
            )
          else
            flash.now[:alert] = t("sign.com.configuration.email.update.failure")
            render(:edit, status: :unprocessable_content)
          end
        end

        def destroy
          @user_email = current_visitor.visitor_emails.find_by!(public_id: params.expect(:id))

          if @user_email.undeletable?
            redirect_to(
              sign_com_configuration_emails_path(ri: params[:ri]),
              alert: t("sign.app.configuration.email.destroy.protected"),
            )
            return
          end

          unless AuthMethodGuard.can_remove_email?(current_visitor, @user_email)
            redirect_to(
              sign_com_configuration_emails_path(ri: params[:ri]),
              alert: t("sign.app.configuration.email.destroy.last_method"),
            )
            return
          end

          @user_email.destroy!
          create_audit_event!(UserChronicleEvent::EMAIL_REMOVED, subject: @user_email)

          redirect_to(
            sign_com_configuration_emails_path(ri: params[:ri]),
            notice: t("sign.app.configuration.email.destroy.success"),
            status: :see_other,
          )
        end

        private

        def create_audit_event!(event_id, subject:)
          ChronicleRecord.connected_to(role: :writing) do
            UserChronicleEvent.find_or_create_by!(id: event_id)
            UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
          end

          UserChronicle.create!(
            actor_type: "Visitor",
            actor_id: current_visitor.id,
            event_id: event_id,
            subject_id: subject.id.to_s,
            subject_type: subject.class.name,
            occurred_at: Time.current,
          )
        end

        def email_preference_params
          params.fetch(:visitor_email, {}).permit(:promotional, :notifiable)
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
