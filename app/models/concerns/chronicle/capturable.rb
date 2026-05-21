# typed: false
# frozen_string_literal: true

class Chronicle
  module Capturable
    extend ActiveSupport::Concern

    class_methods do
      def capture(action:, actor: nil, subject: nil, reason: nil, metadata: {}, changeset: {},
                  request_id: nil, ip_address: nil, user_agent: nil, visibility_contexts: [], &block)
        occurred_at = Time.current
        event_uuid = SecureRandom.uuid
        chronicle = write_capture_intent(
          event_uuid: event_uuid,
          action: action,
          actor: actor,
          subject: subject,
          reason: reason,
          metadata: metadata,
          changeset: changeset,
          request_id: request_id,
          ip_address: ip_address,
          user_agent: user_agent,
          occurred_at: occurred_at,
          visibility_contexts: visibility_contexts,
        )

        result = block&.call
        write_capture_result_or_invalidate(
          chronicle,
          "succeeded",
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
        ) if chronicle.present?
        log_missing_capture_intent_guarantee(
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
        ) if chronicle.blank?
        result
      rescue StandardError
        write_capture_failure_result_or_invalidate(
          chronicle,
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
        ) if chronicle.present?
        raise
      end

      private

      def write_capture_intent(event_uuid:, action:, actor:, subject:, reason:, metadata:, changeset:,
                               request_id:, ip_address:, user_agent:, occurred_at:, visibility_contexts:)
        Chronicle::IntentWriter.call(
          event_uuid: event_uuid,
          action: action,
          actor: actor,
          subject: subject,
          reason: reason,
          metadata: metadata,
          changeset: changeset,
          request_id: request_id,
          ip_address: ip_address,
          user_agent: user_agent,
          occurred_at: occurred_at,
          visibility_contexts: visibility_contexts,
        )
      rescue StandardError => e
        Chronicle::FallbackRecorder.call(
          event: "chronicle.intent_write_failed",
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
          error: e,
          manual_recovery_required: true,
        )
        nil
      end

      def write_capture_result_or_invalidate(chronicle, result, event_uuid:, request_id:, action:, actor:, subject:)
        Chronicle::ResultWriter.call(
          chronicle: chronicle,
          result: result,
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
        )
      rescue StandardError => e
        invalidate_capture_or_log_failure(
          chronicle,
          e,
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
        )
      end

      def write_capture_failure_result_or_invalidate(chronicle, event_uuid:, request_id:, action:, actor:, subject:)
        Chronicle::ResultWriter.call(
          chronicle: chronicle,
          result: "failed",
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
        )
      rescue StandardError => e
        invalidate_capture_or_log_failure(
          chronicle,
          e,
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
        )
      end

      def invalidate_capture_or_log_failure(chronicle, error, event_uuid:, request_id:, action:, actor:, subject:)
        Chronicle::Invalidator.call(
          chronicle: chronicle,
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
          error: error,
        )
      rescue StandardError => e
        Chronicle::FallbackRecorder.call(
          event: "chronicle.invalidation_failed",
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
          error: e,
          manual_recovery_required: true,
        )
        Chronicle::FallbackRecorder.call(
          event: "chronicle.manual_recovery_required",
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
          error: error,
          manual_recovery_required: true,
        )
      end

      def log_missing_capture_intent_guarantee(event_uuid:, request_id:, action:, actor:, subject:)
        Chronicle::FallbackRecorder.call(
          event: "chronicle.guarantee_failed",
          event_uuid: event_uuid,
          request_id: request_id,
          action: action,
          actor: actor,
          subject: subject,
          manual_recovery_required: true,
        )
      end
    end
  end
end
