# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      module OperatorLifecycleRequests
        class ExecutionsController < PrivateController
          before_action :authenticate_operator!
          before_action :set_request

          def create
            return if require_step_up!(scope: "operator_lifecycle") == false

            authorize!(@operator_lifecycle_request, to: :execute?)
            result = ::Org::OperatorLifecycle::Execute.call(
              request: @operator_lifecycle_request,
              actor: current_operator,
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
                sign_org_configuration_operator_lifecycle_request_path(result.request),
                notice: t("sign.org.configuration.operator_lifecycle_requests.execute.success"),
              )
            else
              redirect_to(
                sign_org_configuration_operator_lifecycle_request_path(result.request),
                alert: result.error,
              )
            end
          end
        end
      end
    end
  end
end
