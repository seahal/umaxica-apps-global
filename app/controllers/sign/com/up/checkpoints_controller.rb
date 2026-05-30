# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      class CheckpointsController < Sign::Com::ApplicationController
        include Sign::Up::SequenceControllerSupport

        AUTHENTICATION_MODE = :guest

        before_action :load_sign_up_checkpoint_ticket, only: :show
        before_action :load_sign_up_ticket, only: :destroy
        before_action -> { authorize_sign_up_participant!(:enter_checkpoint?) }, only: :show
        before_action :authorize_sign_up_cancellation!, only: :destroy

        def show
          enter_sign_up_checkpoint!
        end

        def destroy
          result = SignUp::Cancellation.call(cycle: @sign_up_ticket, actor_context: Actor.authn)
          return render_sign_up_result(result) unless result.success?

          sign_up_session_state.clear_all!
          redirect_to(
            "/",
            notice: t("sign.com.registration.cancelled_retry_later"),
          )
        end

        private

        def authorize_sign_up_cancellation!
          return if allowed_to?(:cancel?, sign_up_policy_context, with: SignUp::TicketPolicy)

          render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
        end

        def sign_up_surface = :com

        def sign_up_ticket_class = VisitorSignUpFlow

        def sign_up_sequence_session_key = :sign_com_up_sequence_id
      end
    end
  end
end
