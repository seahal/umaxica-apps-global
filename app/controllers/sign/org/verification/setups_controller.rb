# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Verification
      class SetupsController < Sign::Org::PrivateController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!

        def new
          @rt = params[:rt].to_s.presence
          @return_to = setup_return_to_path(@rt, root_path: sign_org_configuration_path(ri: params[:ri]))
          @missing_methods = step_up_supported_methods - configured_step_up_methods

          return unless @missing_methods.empty?

          safe_redirect_to(
            verification_redirect_path(rt: @rt),
            fallback: actor_root_path(ri: params[:ri]),
            status: :found,
          )
        end
      end
    end
  end
end
