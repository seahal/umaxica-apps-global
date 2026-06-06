# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      class GuardsController < ::Sign::Com::ApplicationController
        include SignUpSequenceControllerSupport

        AUTHENTICATION_MODE = :open

        before_action :hide_sign_up_auth_navigation

        def show
          cycle = validated_guard_cycle
          return redirect_to(sign_up_restart_path) unless cycle

          redirect_to(sign_com_up_check_path(ri: params[:ri], pt: guard_pt_for(cycle)))
        end

        private

        def sign_up_surface = :com

        def sign_up_ticket_class = VisitorSignUpFlow

        def sign_up_sequence_session_key = :sign_com_up_sequence_id

        def validated_guard_cycle
          return if path_target_value.present? && signed_pt_param.blank?

          cycle = sign_up_flow_locator.current
          return unless cycle
          return if cycle.return_to.present? && signed_pt_token(cycle.return_to).blank?

          cycle
        end

        def guard_pt_for(cycle)
          signed_pt_param.presence || signed_pt_token(cycle.return_to)
        end
      end
    end
  end
end
