# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Settings
      class TelephonesController < Acme::App::ApplicationController
        include ::Verification::Client

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_telephones!, only: :index

        def index
          @client_telephones = current_client.client_telephones.order(created_at: :asc)
        end

        def destroy
          telephone = current_client.client_telephones.find_by!(public_id: params(:id))
          authorize!(telephone)

          unless AuthMethodGuard.can_remove_telephone?(current_client, telephone)
            redirect_to(
              acme_app_settings_telephones_path(ri: params[:ri]),
              alert: t("sign.app.settings.telephone.destroy.last_method"),
            )
            return
          end

          telephone.destroy!
          create_audit_event!(ClientChronicleEvent::TELEPHONE_REMOVED, subject: telephone)

          redirect_to(
            acme_app_settings_telephones_path(ri: params[:ri]),
            notice: t("sign.app.settings.telephone.destroy.success"),
            status: :see_other,
          )
        end

        private

        def authorize_telephones!
          authorize!(ClientTelephone, to: :index?)
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

        def verification_required_action?
          true
        end

        def verification_scope
          "settings_telephone"
        end
      end
    end
  end
end
