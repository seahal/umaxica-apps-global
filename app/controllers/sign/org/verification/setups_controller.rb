# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Verification
      class SetupsController < Sign::Org::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!

        def new
          @pt = params[:pt].to_s.presence
          @pt_destination = setup_pt_path(@pt, root_path: sign_org_settings_path(ri: params[:ri]))
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
