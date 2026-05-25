# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      class CheckpointsController < GuestController
        include Sign::Up::SequenceControllerSupport

        before_action :load_sign_up_ticket
        before_action -> { authorize_sign_up_participant!(:enter_checkpoint?) }, only: :show
        before_action :authorize_sign_up_cancellation!, only: :destroy

        def show
          enter_sign_up_checkpoint!
        end

        def destroy
          result = Sign::App::Up::SocialCancellation.call(cycle: @sign_up_ticket)
          return render_sign_up_result(result) unless result.success?

          sign_up_cycle_locator.clear!
          session.delete(sign_up_sequence_session_key)
          redirect_to(new_sign_app_up_path(ri: params[:ri]), notice: t("sign.app.registration.cancelled"))
        end

        private

        def authorize_sign_up_cancellation!
          return if allowed_to?(:cancel?, sign_up_policy_context, with: SignUp::TicketPolicy)

          render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
        end

        def sign_up_surface = :app

        def sign_up_ticket_class = ClientSignUpCycle

        def sign_up_sequence_session_key = :sign_app_up_sequence_id
      end
    end
  end
end
