# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      module Guard
        class BaseController < Sign::Com::ApplicationController
          include Sign::Up::ExplicitStepControllerSupport

          AUTHENTICATION_MODE = :open

          def show
            gate = SignUp::StepGate.for_show(
              controller: self,
              surface: sign_up_surface,
              family: sign_up_family,
              step: first_step,
            )
            return redirect_to(sign_up_restart_path) unless gate.success?

            @sign_up_ticket = gate.ticket
            redirect_to(gate.redirect_to || explicit_step_path(first_step))
          end

          private

          def sign_up_surface = :com

          def sign_up_ticket_class = VisitorSignUpFlow

          def sign_up_sequence_session_key = :sign_com_up_sequence_id

          def first_step
            SignUp::RequirementRegistry.for_entry(
              surface: sign_up_surface,
              entry_method: sign_up_family,
            ).requirements.first
          end

          def explicit_step_path(step)
            helper = SignUp::StepGate::STEP_ROUTES.fetch(sign_up_surface).fetch(sign_up_family).fetch(step)
            public_send(helper, ri: params[:ri], pt: signed_pt_param)
          end
        end
      end
    end
  end
end
