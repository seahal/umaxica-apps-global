# typed: false
# frozen_string_literal: true

module Org
  module OperatorLifecycle
    class Execute
      GRACE_PERIOD = 31.days

      def self.call(request:, actor:)
        new(request: request, actor: actor).call
      end

      def initialize(request:, actor:)
        @request = request
        @actor = actor
      end

      def call
        return failure("Only approved requests can be executed") unless request.approved?
        return failure("Requester cannot execute their own lifecycle request") if requested_by_actor?

        invitation = nil
        OrgPrincipalRecord.transaction do
          invitation = execute_action!
          request.update!(
            status: OperatorLifecycleRequest::STATUS_EXECUTED,
            executed_by_operator: actor,
            executed_at: Time.current,
            invitation_id: invitation&.id,
          )
        end

        Result.new(success: true, request: request, error: nil, invitation: invitation)
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record.errors.full_messages.to_sentence)
      end

      private

      attr_reader :request, :actor

      def execute_action!
        case request.action
        when OperatorLifecycleRequest::ACTION_JOIN
          create_invitation!
        when OperatorLifecycleRequest::ACTION_WITHDRAW, OperatorLifecycleRequest::ACTION_SUSPEND
          suspend_operator!
          nil
        when OperatorLifecycleRequest::ACTION_TERMINATE
          terminate_operator!
          nil
        when OperatorLifecycleRequest::ACTION_RESTORE
          restore_operator!
          nil
        else
          raise ActiveRecord::RecordInvalid, request
        end
      end

      def create_invitation!
        result = Org::OperatorLifecycle::InvitationIssuer.call(request: request, actor: actor)
        raise ActiveRecord::RecordInvalid, request unless result.success?

        result.invitation
      end

      def suspend_operator!
        target = request.target_operator
        return if target.blank?

        ensure_not_last_active_operator!(target)
        revoke_target_sessions!(target)
        now = Time.current
        target.update!(
          withdrawal_started_at: target.withdrawal_started_at || now,
          deactivated_at: target.deactivated_at || now,
          discarded_at: now,
          purged_at: now + GRACE_PERIOD,
        )
      end

      def terminate_operator!
        target = request.target_operator
        return if target.blank?

        ensure_not_last_active_operator!(target)
        revoke_target_sessions!(target)
        now = Time.current
        target.update!(
          withdrawal_started_at: target.withdrawal_started_at || now,
          deactivated_at: target.deactivated_at || now,
          withdrawn_at: target.withdrawn_at || now,
          discarded_at: now,
          purged_at: now,
        )
      end

      def restore_operator!
        target = request.target_operator
        return if target.blank?

        target.update!(
          withdrawal_started_at: nil,
          deactivated_at: nil,
          withdrawn_at: nil,
          discarded_at: Float::INFINITY,
          purged_at: Float::INFINITY,
        )
      end

      def revoke_target_sessions!(target)
        target.staff_tokens.not_revoked.find_each(&:revoke!)
      end

      def ensure_not_last_active_operator!(target)
        active_count =
          Operator
            .where(deactivated_at: nil, withdrawn_at: nil)
            .where(Operator.arel_table[:discarded_at].gt(Time.current))
            .where.not(id: target.id)
            .count
        return if active_count.positive?

        request.errors.add(:base, "Cannot deactivate the last active operator")
        raise ActiveRecord::RecordInvalid, request
      end

      def requested_by_actor?
        request.requested_by_operator_id == actor.id
      end

      def failure(error)
        Result.new(success: false, request: request, error: error, invitation: nil)
      end
    end
  end
end
