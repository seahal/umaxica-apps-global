# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class EmailsController < ApplicationController
        auth_required!

        include ::Verification::User

        before_action :authenticate_customer!

        def index
          @user_emails = current_customer.customer_emails
        end

        def edit
          @user_email = current_customer.customer_emails.find_by!(public_id: params.expect(:id))
        end

        def destroy
          @user_email = current_customer.customer_emails.find_by!(public_id: params.expect(:id))

          if @user_email.undeletable?
            redirect_to(
              sign_com_configuration_emails_path(ri: params[:ri]),
              alert: t("sign.app.configuration.email.destroy.protected"),
            )
            return
          end

          unless AuthMethodGuard.can_remove_email?(current_customer, @user_email)
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
            actor_type: "Customer",
            actor_id: current_customer.id,
            event_id: event_id,
            subject_id: subject.id.to_s,
            subject_type: subject.class.name,
            occurred_at: Time.current,
          )
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
