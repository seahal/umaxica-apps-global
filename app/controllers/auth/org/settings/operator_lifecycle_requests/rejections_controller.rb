# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      module OperatorLifecycleRequests
        class RejectionsController < ::Auth::Org::ApplicationController
          AUTHENTICATION_MODE = :private

          before_action :authenticate_operator!
          before_action :set_request

          def create
            return if require_step_up!(scope: "operator_lifecycle") == false

            authorize!(@operator_lifecycle_request, to: :reject?)
            result = ::OrgOperatorLifecycleReject.call(
              request: @operator_lifecycle_request,
              actor: current_operator,
              reason: params.dig(:operator_lifecycle_request, :rejection_reason),
            )
            redirect_after_result(result)
          end

          private

          def set_request
            @operator_lifecycle_request =
              OperatorLifecycleRequest.find_by!(public_id: params.expect(:operator_lifecycle_request_id))
          end

          def redirect_after_result(result)
            if result.success?
              redirect_to(
                auth_org_settings_operator_lifecycle_request_path(result.request),
              )
            else
              redirect_to(
                auth_org_settings_operator_lifecycle_request_path(result.request),
              )
            end
          end
        end
      end
    end
  end
end
