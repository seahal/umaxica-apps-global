# typed: false
# frozen_string_literal: true

class Chronicle
  class Capture < ApplicationService
    def self.call(...)
      new(...).call
    end

    def initialize(action:, actor: nil, subject: nil, reason: nil, metadata: {}, changeset: {},
                   request_id: nil, ip_address: nil, user_agent: nil, visibility_contexts: [], &block)
      super()
      @action = action
      @actor = actor
      @subject = subject
      @reason = reason
      @metadata = metadata
      @changeset = changeset
      @request_id = request_id
      @ip_address = ip_address
      @user_agent = user_agent
      @occurred_at = Time.current
      @visibility_contexts = visibility_contexts
      @event_uuid = SecureRandom.uuid
      @block = block
    end

    def call
      chronicle = write_intent
      result = execute_business_block
      write_result_or_invalidate(chronicle, "succeeded") if chronicle.present?
      log_missing_intent_guarantee if chronicle.blank?
      result
    rescue StandardError
      write_failure_result_or_invalidate(chronicle) if chronicle.present?
      raise
    end

    private

    attr_reader :action, :actor, :subject, :reason, :metadata, :changeset, :request_id, :ip_address,
                :user_agent, :occurred_at, :visibility_contexts, :event_uuid, :block

    def write_intent
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

    def execute_business_block
      return unless block

      block.call
    end

    def write_result_or_invalidate(chronicle, result)
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
      invalidate_or_log_failure(chronicle, e)
    end

    def write_failure_result_or_invalidate(chronicle)
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
      invalidate_or_log_failure(chronicle, e)
    end

    def invalidate_or_log_failure(chronicle, error)
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

    def log_missing_intent_guarantee
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
