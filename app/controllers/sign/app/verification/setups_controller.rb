# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Verification
      class SetupsController < Sign::App::PrivateController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!

        def new
          @rt = params[:rt].to_s.presence
          @return_to = setup_return_to_path(@rt, root_path: sign_app_configuration_path(ri: params[:ri]))
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
