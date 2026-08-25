# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module EnforcementCases
        # The review is a noun resource so it remains distinct from the
        # operator action that created the Case. EnforcementAppeal enforces
        # reviewer separation again at the model boundary.
        class AppealReviewsController < Base::Org::ApplicationController
          include EnforcementCaseRealmResolvable

          AUTHENTICATION_MODE = :private

          declare_authentication_mode! :private
          before_action :require_enforcement_step_up!
          before_action :set_enforcement_case

          def create
            authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :review_appeal?)

            appeal = @enforcement_case.appeal
            raise ActiveRecord::RecordNotFound, "appeal not found" unless appeal

            appeal.resolve!(
              reviewer_operator_public_id: current_operator.public_id,
              resolution_code: params.expect(:resolution_code),
            )
            render json: { public_id: appeal.public_id, state: appeal.state }, status: :ok
          rescue EnforcementAppeal::ReviewerSeparationError, EnforcementAppeal::InvalidResolutionError,
                 ActiveRecord::RecordInvalid, ArgumentError => e
            render json: { error: e.message }, status: :unprocessable_content
          end

          private

          def require_enforcement_step_up!
            require_step_up!(scope: "enforcement_case_review_appeal")
          end

          def set_enforcement_case
            @enforcement_case = enforcement_case_class.find_by!(public_id: params.expect(:enforcement_case_id))
          end
        end
      end
    end
  end
end
