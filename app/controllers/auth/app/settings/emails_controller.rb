# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      class EmailsController < ::Auth::App::ApplicationController
        include CloudflareTurnstile
        include ::VerificationClient

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_emails!, only: :index

        def index = redirect_to(acme_app_identity_emails_path(ri: params[:ri]), status: :see_other)

        def edit
          redirect_to(
            edit_acme_app_identity_email_path(params.expect(:id), ri: params[:ri]),
            status: :see_other,
          )
        end

        def update
          head :gone
        end

        def destroy
          head :gone
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

        def verification_required_action? = false
      end
    end
  end
end
