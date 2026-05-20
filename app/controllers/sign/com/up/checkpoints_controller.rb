# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      class CheckpointsController < GuestController
        include Sign::Up::SequenceControllerSupport

        before_action :load_sign_up_ticket
        before_action -> { authorize_sign_up_participant!(:enter_checkpoint?) }, only: :show
        before_action -> { authorize_sign_up_requirement!(:clear_requirement?) }, only: :update

        def show
          run_sign_up_event(:enter_checkpoint)
        end

        def update
          return unless persist_sign_up_birthdate_requirement

          run_sign_up_event(:clear_requirement, payload: { requirement: params[:requirement] })
        end

        private

        def sign_up_surface = :com

        def sign_up_ticket_class = VisitorSignUpCycle

        def sign_up_sequence_session_key = :sign_com_up_sequence_id
      end
    end
  end
end
