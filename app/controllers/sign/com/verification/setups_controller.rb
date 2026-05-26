# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Verification
      class SetupsController < Sign::Com::PrivateController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!

        def new
          @pt = params[:pt].to_s.presence
          @pt_destination = setup_pt_path(@pt, root_path: sign_com_configuration_path(ri: params[:ri]))
          @missing_methods = %i(email_otp passkey) - configured_step_up_methods

          return unless @missing_methods.empty?

          safe_redirect_to(
            verification_redirect_path(pt: @pt),
            fallback: sign_com_root_path(ri: params[:ri]),
            status: :found,
          )
        end
      end
    end
  end
end
