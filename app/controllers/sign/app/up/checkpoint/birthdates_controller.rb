# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      module Checkpoint
        class BirthdatesController < Sign::App::ApplicationController
          include Sign::Up::SequenceControllerSupport

          AUTHENTICATION_MODE = :guest

          before_action :load_sign_up_ticket
          before_action -> { authorize_sign_up_requirement_or_cleared_continue!(:clear_requirement?) }

          def update
            clear_sign_up_birthdate_requirement
          end

          private

          def sign_up_surface = :app

          def sign_up_ticket_class = ClientSignUpCycle

          def sign_up_sequence_session_key = :sign_app_up_sequence_id
        end
      end
    end
  end
end
