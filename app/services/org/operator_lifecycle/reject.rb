# typed: false
# frozen_string_literal: true

module Org
  module OperatorLifecycle
    class Reject
      def self.call(request:, actor:, reason: nil)
        new(request: request, actor: actor, reason: reason).call
      end

      def initialize(request:, actor:, reason: nil)
        @request = request
        @actor = actor
        @reason = reason
      end

      def call
        return failure("Only pending requests can be rejected") unless request.pending?
        return failure("Requester cannot reject their own lifecycle request") if requested_by_actor?

        request.update!(
          status: OperatorLifecycleRequest::STATUS_REJECTED,
          rejected_by_operator: actor,
          rejected_at: Time.current,
          rejection_reason: reason.to_s,
        )
        Result.new(success: true, request: request, error: nil, invitation: nil)
      end

      private

      attr_reader :request, :actor, :reason

      def requested_by_actor?
        request.requested_by_operator_id == actor.id
      end

      def failure(error)
        Result.new(success: false, request: request, error: error, invitation: nil)
      end
    end
  end
end
