# typed: false
# frozen_string_literal: true

module Org
  module OperatorLifecycle
    class Approve
      def self.call(request:, actor:)
        new(request: request, actor: actor).call
      end

      def initialize(request:, actor:)
        @request = request
        @actor = actor
      end

      def call
        return failure("Only pending requests can be approved") unless request.pending?
        return failure("Requester cannot approve their own lifecycle request") if requested_by_actor?

        request.update!(
          status: OperatorLifecycleRequest::STATUS_APPROVED,
          approved_by_operator: actor,
          approved_at: Time.current,
        )
        Result.new(success: true, request: request, error: nil, invitation: nil)
      end

      private

      attr_reader :request, :actor

      def requested_by_actor?
        request.requested_by_operator_id == actor.id
      end

      def failure(error)
        Result.new(success: false, request: request, error: error, invitation: nil)
      end
    end
  end
end
