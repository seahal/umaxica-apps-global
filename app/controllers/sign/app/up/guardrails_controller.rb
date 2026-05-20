# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      class GuardrailsController < GuestController
        include Sign::Up::SequenceControllerSupport

        before_action :load_sign_up_ticket
        before_action -> { authorize_sign_up_participant!(:enter_guardrail?) }

        def show
          run_sign_up_event(:enter_guardrail)
        end

        private

        def sign_up_surface = :app

        def sign_up_ticket_class = ClientSignUpCycle

        def sign_up_sequence_session_key = :sign_app_up_sequence_id
      end
    end
  end
end
