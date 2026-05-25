# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Verification
      class SetupsController < Sign::Com::PrivateController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!

        def new
          @rt = params[:rt].to_s.presence
          @return_to = setup_return_to_path(@rt, root_path: sign_com_configuration_path(ri: params[:ri]))
          @missing_methods = %i(email_otp passkey) - configured_step_up_methods

          return unless @missing_methods.empty?

          safe_redirect_to(
            verification_redirect_path(rt: @rt),
            fallback: sign_com_root_path(ri: params[:ri]),
            status: :found,
          )
        end
      end
    end
  end
end
