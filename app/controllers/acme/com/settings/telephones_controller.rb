# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Settings
      class TelephonesController < Acme::Com::ApplicationController
        include ::VerificationVisitor

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!
        before_action :authorize_telephones!, only: :index

        def index
          @client_telephones = current_visitor.visitor_telephones.order(created_at: :asc)
        end

        def destroy
          telephone = current_visitor.visitor_telephones.find_by!(public_id: params(:id))
          authorize!(telephone)

          unless AuthMethodGuard.can_remove_telephone?(current_visitor, telephone)
            redirect_to(
              acme_com_settings_telephones_path(ri: params[:ri]),
              alert: t("sign.app.settings.telephone.destroy.last_method"),
            )
            return
          end

          telephone.destroy!
          create_audit_event!(ClientChronicleEvent::TELEPHONE_REMOVED, subject: telephone)

          redirect_to(
            acme_com_settings_telephones_path(ri: params[:ri]),
            notice: t("sign.app.settings.telephone.destroy.success"),
            status: :see_other,
          )
        end

        private

        def authorize_telephones!
          authorize!(VisitorTelephone, to: :index?)
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
