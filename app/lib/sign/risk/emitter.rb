# typed: false
# frozen_string_literal: true

module Sign
  module Risk
    class Emitter
      # TODO: PostgreSQL INSERT latency (~1-3ms) is higher than Redis ZADD (~0.1ms).
      #   For high-throughput auth endpoints, consider async INSERT via SolidQueue job
      #   if p99 latency becomes a concern. Monitor occurrence DB write times in production.

      def self.emit(name, **payload)
        return unless feature_enabled?

        event = Event.new(name, payload: payload)
        persist(event)
      end

      def self.persist(event)
        user_id = event.payload[:user_id]
        staff_id = event.payload[:staff_id]
        return unless user_id || staff_id

        context = {
          ip: event.payload[:ip],
          reason: event.payload[:reason],
          occurred_at: event.occurred_at.iso8601,
        }.compact

        if staff_id
          persist_staff_occurrence(event, staff_id, context)
        else
          persist_user_occurrence(event, user_id, context)
        end
      rescue StandardError => e
        Rails.event.error(
          "sign.risk.emitter.persist_failed",
          error_class: e.class.name,
          message: e.message,
          event_name: event.name,
        )
      end

      def self.persist_user_occurrence(event, user_id, context)
        expiry = 1.hour.from_now
        UserOccurrence.create!(
          body: SecureRandom.uuid,
          event_type: "risk.#{event.name}",
          context: context.merge(user_id: user_id),
          status_id: UserOccurrenceStatus::ACTIVE,
          lapses_at: expiry,
          purge_at: expiry,
        )
      end

      def self.persist_staff_occurrence(event, staff_id, context)
        expiry = 1.hour.from_now
        StaffOccurrence.create!(
          body: SecureRandom.uuid,
          event_type: "risk.#{event.name}",
          context: context.merge(staff_id: staff_id),
          status_id: StaffOccurrenceStatus::ACTIVE,
          lapses_at: expiry,
          purge_at: expiry,
        )
      end

      def self.feature_enabled?
        return false if ENV["RISK_ENFORCEMENT_DISABLED"] == "true"

        enabled_config = Rails.configuration.try(:x).try(:risk_enforcement).try(:enabled)
        enabled_config || ENV["RISK_ENFORCEMENT_ENABLED"] == "true" || Rails.env.production?
      end

      private_class_method :persist, :persist_user_occurrence, :persist_staff_occurrence
    end
  end
end
