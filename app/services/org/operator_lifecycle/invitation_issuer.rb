# typed: false
# frozen_string_literal: true

module Org
  module OperatorLifecycle
    class InvitationIssuer
      def self.call(request:, actor:)
        new(request: request, actor: actor).call
      end

      def initialize(request:, actor:)
        @request = request
        @actor = actor
      end

      def call
        Org::InvitationService.create(
          organization_id: request.organization_id,
          email: request.target_email,
          invited_by: actor,
          role_id: request.role_id,
        )
      end

      private

      attr_reader :request, :actor
    end
  end
end
