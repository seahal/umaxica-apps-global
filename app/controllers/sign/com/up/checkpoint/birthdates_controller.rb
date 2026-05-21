# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      module Checkpoint
        class BirthdatesController < GuestController
          include Sign::Up::SequenceControllerSupport

          before_action :load_sign_up_ticket
          before_action -> { authorize_sign_up_requirement!(:clear_requirement?) }

          def update
            return unless persist_sign_up_birthdate_requirement

            run_sign_up_requirement_event(payload: { requirement: :birthdate })
          end

          private

          def sign_up_surface = :com

          def sign_up_ticket_class = VisitorSignUpCycle

          def sign_up_sequence_session_key = :sign_com_up_sequence_id
        end
      end
    end
  end
end
