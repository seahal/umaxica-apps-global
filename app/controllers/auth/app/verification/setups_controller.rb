# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Verification
      class SetupsController < ::Auth::App::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!

        def new
          @pt = params[:pt].to_s.presence
          @pt_destination = setup_pt_path(@pt, root_path: auth_app_settings_path(ri: params[:ri]))
          @missing_methods = step_up_supported_methods - configured_step_up_methods

          return unless @missing_methods.empty?

          safe_redirect_to(
            verification_redirect_path(pt: @pt),
            fallback: actor_root_path(ri: params[:ri]),
            status: :found,
          )
        end
      end
    end
  end
end
