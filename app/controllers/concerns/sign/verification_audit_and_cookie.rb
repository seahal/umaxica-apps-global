# typed: false
# frozen_string_literal: true

module Sign
  module VerificationAuditAndCookie
    extend ActiveSupport::Concern

    private

    def create_audit_event!(event_id, subject:)
      ChronicleRecord.connected_to(role: :writing) do
        verification_audit_event_class.find_or_create_by!(id: event_id)
        verification_audit_level_class.find_or_create_by!(id: verification_default_activity_level_id)
      end

      verification_activity_model.create!(
        actor_type: verification_actor_type,
        actor_id: current_verification_actor.id,
        event_id: event_id,
        subject_id: subject.id.to_s,
        subject_type: subject.class.name,
        occurred_at: Time.current,
      )
    end

    def verification_audit_event_class
      raise NotImplementedError, "#{self.class} must define #verification_audit_event_class"
    end

    def verification_audit_level_class
      raise NotImplementedError, "#{self.class} must define #verification_audit_level_class"
    end

    def verification_default_activity_level_id
      raise NotImplementedError, "#{self.class} must define #verification_default_activity_level_id"
    end

    def verification_activity_model
      raise NotImplementedError, "#{self.class} must define #verification_activity_model"
    end

    def current_verification_actor
      raise NotImplementedError, "#{self.class} must define #current_verification_actor"
    end

    def verification_actor_type
      raise NotImplementedError, "#{self.class} must define #verification_actor_type"
    end
  end
end
