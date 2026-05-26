# typed: false
# frozen_string_literal: true

module Identity
  class Audit
    def self.record!(actor:, event_id:, subject: actor, action: nil, ip_address: nil, user_agent: nil,
                     metadata: {}, occurred_at: Time.current)
      new(
        actor: actor,
        event_id: event_id,
        subject: subject,
        action: action,
        ip_address: ip_address,
        user_agent: user_agent,
        metadata: metadata,
        occurred_at: occurred_at,
      ).record!
    end

    def initialize(actor:, event_id:, subject:, action:, ip_address:, user_agent:, metadata:, occurred_at:)
      @actor = actor
      @event_id = event_id
      @subject = subject || actor
      @action = action
      @ip_address = ip_address
      @user_agent = user_agent
      @metadata = metadata || {}
      @occurred_at = occurred_at
    end

    def record!
      ChronicleRecord.connected_to(role: :writing) do
        ensure_dependencies!
        chronicle_class.create!(
          actor: actor,
          subject_type: subject.class.name,
          subject_id: subject.id.to_s,
          event_id: event_id,
          level_id: level_id,
          occurred_at: occurred_at,
          ip_address: ip_address,
          context: context,
        )
      end
    end

    private

    attr_reader :actor, :event_id, :subject, :action, :ip_address, :user_agent, :metadata, :occurred_at

    def chronicle_class
      actor.is_a?(Operator) ? OperatorChronicle : ClientChronicle
    end

    def event_class
      actor.is_a?(Operator) ? OperatorChronicleEvent : ClientChronicleEvent
    end

    def level_class
      actor.is_a?(Operator) ? OperatorChronicleLevel : ClientChronicleLevel
    end

    def level_id
      level_class::NOTHING
    end

    def ensure_dependencies!
      event_class.find_or_create_by!(id: event_id)
      level_class.find_or_create_by!(id: level_id)
    end

    def context
      {
        action: action,
        user_agent: user_agent,
      }.merge(metadata).compact
    end
  end
end
