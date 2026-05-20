# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class OperatorLifecycleRequestsController < PrivateController
        before_action :authenticate_operator!
        before_action :set_request, only: %i(show)
        before_action :set_invitation, only: %i(show)

        def index
          authorize!(OperatorLifecycleRequest)
          @operator_lifecycle_requests = OperatorLifecycleRequest.order(created_at: :desc).limit(50)
        end

        def show
          authorize!(@operator_lifecycle_request)
        end

        def new
          authorize!(OperatorLifecycleRequest)
          @operator_lifecycle_request = OperatorLifecycleRequest.new(
            action: params[:action_kind].presence,
            target_operator: target_operator_from_params,
          )
        end

        def create
          return if require_step_up!(scope: "operator_lifecycle") == false

          authorize!(OperatorLifecycleRequest)
          result = ::Org::OperatorLifecycle::RequestCreate.call(
            actor: current_operator,
            attributes: lifecycle_request_params,
          )
          @operator_lifecycle_request = result.request

          if result.success?
            redirect_to(
              sign_org_configuration_operator_lifecycle_request_path(result.request),
              notice: t(".success"),
            )
          else
            flash.now[:alert] = result.error
            render :new, status: :unprocessable_content
          end
        end

        private

        def set_request
          @operator_lifecycle_request = OperatorLifecycleRequest.find_by!(public_id: params.expect(:id))
        end

        def set_invitation
          return if @operator_lifecycle_request.invitation_id.blank?

          @organization_invitation = OrganizationInvitation.find_by(id: @operator_lifecycle_request.invitation_id)
        end

        def lifecycle_request_params
          params
            .expect(operator_lifecycle_request: %i(action target_operator_public_id target_email organization_id
                                                   role_id reason))
            .to_h
            .symbolize_keys
        end

        def target_operator_from_params
          public_id = params[:target_operator_public_id].presence
          return current_operator if public_id.blank? && params[:action_kind].to_s == OperatorLifecycleRequest::ACTION_WITHDRAW
          return nil if public_id.blank?

          Operator.find_by(public_id: Operator.normalize_public_id(public_id))
        end
      end
    end
  end
end
