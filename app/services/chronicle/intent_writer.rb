# typed: false
# frozen_string_literal: true

class Chronicle
  class IntentWriter < ApplicationService
    def initialize(event_uuid:, action:, actor: nil, subject: nil, reason: nil, metadata: {}, changeset: {},
                   request_id: nil, ip_address: nil, user_agent: nil, occurred_at: Time.current,
                   visibility_contexts: [])
      super()
      @event_uuid = event_uuid
      @action = action
      @actor = actor
      @subject = subject
      @reason = reason
      @metadata = metadata
      @changeset = changeset
      @request_id = request_id
      @ip_address = ip_address
      @user_agent = user_agent
      @occurred_at = occurred_at
      @visibility_contexts = Array(visibility_contexts)
    end

    def call
      policy = Chronicle::Recorder.retention_policy_for(
        action: action,
      )

      Chronicle.transaction do
        chronicle = Chronicle.create!(
          event_uuid: event_uuid,
          actor: actor,
          subject: subject,
          chronicle_retention_policy: policy,
          action: action,
          result: "intent",
          reason: reason,
          occurred_at: occurred_at,
          erasable_at: Chronicle::Recorder.erasable_at_for(policy: policy, occurred_at: occurred_at),
          request_id: request_id,
          ip_address: ip_address,
          user_agent: user_agent,
          metadata: metadata,
          changeset: changeset,
        )

        attach_visibility_contexts(chronicle)
        chronicle
      end
    end

    private

    attr_reader :event_uuid, :action, :actor, :subject, :reason, :metadata, :changeset, :request_id,
                :ip_address, :user_agent, :occurred_at, :visibility_contexts

    def attach_visibility_contexts(chronicle)
      visibility_contexts.each do |context|
        resolved_context = resolve_visibility_context(context)
        next if resolved_context.blank?

        ChronicleVisibility.find_or_create_by!(
          chronicle: chronicle,
          chronicle_visibility_context: resolved_context,
        )
      end
    end

    def resolve_visibility_context(context)
      return context if context.is_a?(ChronicleVisibilityContext)

      resolved_context = ChronicleVisibilityContext.find_by(code: context.to_s)
      return resolved_context if resolved_context.present?

      Chronicle::FallbackRecorder.call(
        event: "chronicle.visibility_context_unknown",
        event_uuid: event_uuid,
        request_id: request_id,
        action: action,
        actor: actor,
        subject: subject,
      )
      nil
    end
  end
end
