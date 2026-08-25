# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module EnforcementCases
        # adr/unified-enforcement.md, Break-glass / State machine. Ends an
        # active Case. Break-glass release (permanently_frozen Method Effect,
        # non-appealed permanent_ban) requires the Case to already carry
        # break_glass_approved_by_operator_public_id -- enforced by the CHECK
        # constraint at Case creation, not re-derived here.
        class ReleasesController < Base::Org::ApplicationController
          include EnforcementCaseRealmResolvable

          AUTHENTICATION_MODE = :private

          declare_authentication_mode! :private
          before_action :require_enforcement_step_up!
          before_action :set_enforcement_case

          def create
            authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :release?)

            @enforcement_case.end_case!(reason: release_reason, ended_by_operator_public_id: current_operator.public_id)
            render json: { public_id: @enforcement_case.public_id, state: @enforcement_case.state }, status: :ok
          rescue ActiveRecord::RecordInvalid, ArgumentError => e
            render json: { error: e.message }, status: :unprocessable_content
          end

          private

          def require_enforcement_step_up!
            require_step_up!(scope: "enforcement_case_release")
          end

          def set_enforcement_case
            @enforcement_case = enforcement_case_class.find_by!(public_id: params.expect(:enforcement_case_id))
          end

          def release_reason
            requested = params[:reason].to_s
            return requested if EnforcementCaseApplicable::END_REASONS.include?(requested)

            "revoked"
          end
        end
      end
    end
  end
end
