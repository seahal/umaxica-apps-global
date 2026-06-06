# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      module OperatorLifecycleRequests
        class ApprovalsController < Sign::Org::ApplicationController
          AUTHENTICATION_MODE = :private

          before_action :authenticate_operator!
          before_action :set_request

          def create
            return if require_step_up!(scope: "operator_lifecycle") == false

            authorize!(@operator_lifecycle_request, to: :approve?)
            result = ::OrgOperatorLifecycleApprove.call(
              request: @operator_lifecycle_request,
              actor: current_operator,
            )
            redirect_after_result(result, success_key: "approve")
          end

          private

          def set_request
            @operator_lifecycle_request =
              OperatorLifecycleRequest.find_by!(public_id: params.expect(:operator_lifecycle_request_id))
          end

          def redirect_after_result(result, success_key:)
            notice_key = "sign.org.settings.operator_lifecycle_requests.#{success_key}.success"
            if result.success?
              redirect_to(
                sign_org_settings_operator_lifecycle_request_path(result.request),
                notice: t(notice_key),
              )
            else
              redirect_to(
                sign_org_settings_operator_lifecycle_request_path(result.request),
                alert: result.error,
              )
            end
          end
        end
      end
    end
  end
end
