# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class EmailsController < ::Base::Com::ApplicationController
        include CloudflareTurnstile
        include ::VerificationVisitor

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!
        before_action :authorize_emails!, only: :index

        def index
          @client_emails = current_visitor.visitor_emails
        end

        def edit
          @user_email = current_visitor.visitor_emails.find_by!(public_id: params(:id))
          authorize!(@user_email)
        end

        def update
          @user_email = current_visitor.visitor_emails.find_by!(public_id: params(:id))
          authorize!(@user_email)

          unless cloudflare_turnstile_stealth_validation["success"]
            @user_email.errors.add(:base, t("turnstile_error"))
            render(:edit, status: :unprocessable_content)
            return
          end

          if @user_email.update(email_preference_params)
            redirect_to(
              edit_base_com_identity_email_path(@user_email.public_id, ri: params[:ri]),
              notice: t("sign.com.settings.email.update.success"),
              status: :see_other,
            )
          else
            @user_email.errors.add(:base, t("sign.com.settings.email.update.failure"))
            render(:edit, status: :unprocessable_content)
          end
        end

        def destroy
          @user_email = current_visitor.visitor_emails.find_by!(public_id: params(:id))
          authorize!(@user_email)

          if @user_email.undeletable?
            redirect_to(
              base_com_identity_emails_path(ri: params[:ri]),
              alert: t("sign.app.settings.email.destroy.protected"),
            )
            return
          end

          unless AuthMethodGuard.can_remove_email?(current_visitor, @user_email)
            redirect_to(
              base_com_identity_emails_path(ri: params[:ri]),
              alert: t("sign.com.settings.email.destroy.last_method"),
            )
            return
          end

          @user_email.destroy!
          create_audit_event!(ClientChronicleEvent::EMAIL_REMOVED, subject: @user_email)

          redirect_to(
            base_com_identity_emails_path(ri: params[:ri]),
            notice: t("sign.com.settings.email.destroy.success"),
            status: :see_other,
          )
        end

        private

        def authorize_emails!
          authorize!(VisitorEmail, to: :index?)
        end

        def create_audit_event!(event_id, subject:)
          ChronicleRecord.connected_to(role: :writing) do
            ClientChronicleEvent.find_or_create_by!(id: event_id)
            ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
          end

          ClientChronicle.create!(
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
          "settings_email"
        end
      end
    end
  end
end
