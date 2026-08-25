# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module EnforcementCases
        # adr/unified-enforcement.md, Approval: the approving operator must
        # differ from the applying operator -- enforced as a CHECK constraint
        # (chk_*_enforcement_cases_approval_separation), not only here. Effects
        # are attached and confirmed at approval time, never carried over
        # unreviewed from the initial `create`.
        class ApprovalsController < Base::Org::ApplicationController
          include EnforcementCaseRealmResolvable

          AUTHENTICATION_MODE = :private

          declare_authentication_mode! :private
          before_action :require_enforcement_step_up!
          before_action :set_enforcement_case

          def create
            authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :approve?)

            @enforcement_case.approved_by_operator_public_id = current_operator.public_id
            attach_requested_effects!(@enforcement_case)
            @enforcement_case.apply!
            render json: { public_id: @enforcement_case.public_id, state: @enforcement_case.state }, status: :ok
          rescue ActiveRecord::RecordInvalid, ArgumentError, EnforcementCaseApplicable::ApprovalRequiredError => e
            render json: { error: e.message }, status: :unprocessable_content
          end

          private

          def require_enforcement_step_up!
            require_step_up!(scope: "enforcement_case_approve")
          end

          def set_enforcement_case
            @enforcement_case = enforcement_case_class.find_by!(public_id: params.expect(:enforcement_case_id))
          end

          def attach_requested_effects!(enforcement_case)
            if (attrs = params[:principal_effect]).present?
              enforcement_case.build_principal_effect(
                attrs.permit(
                  :access_blocking, :recovery_blocked, :reactivation_blocked,
                  :withdrawal_purge_blocked, :principal_hard_delete_blocked, :profile_effect,
                ).to_h.merge(principal_public_id: enforcement_case.principal_public_id, effective_at: Time.current),
              )
            end
            return if (attrs = params[:authentication_method_effect]).blank?

            enforcement_case.authentication_method_effects.build(
              attrs.permit(:authentication_method, :effect).to_h.merge(
                principal_public_id: enforcement_case.principal_public_id, effective_at: Time.current,
              ),
            )
          end
        end
      end
    end
  end
end
