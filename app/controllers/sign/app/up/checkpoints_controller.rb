# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      class CheckpointsController < Sign::App::ApplicationController
        include SignUpSequenceControllerSupport

        AUTHENTICATION_MODE = :guest

        before_action :hide_sign_up_auth_navigation
        before_action :load_sign_up_checkpoint_ticket, only: :show
        before_action :load_sign_up_ticket_for_destroy, only: :destroy
        before_action -> { authorize_sign_up_participant!(:enter_checkpoint?) }, only: :show
        before_action :authorize_sign_up_cancellation!, only: :destroy

        def show
          enter_sign_up_checkpoint!
        end

        def destroy
          result = cancel_sign_up_ticket
          return render_sign_up_result(result) unless result.success?

          sign_up_session_state.clear_all!
          redirect_to(
            "/",
            notice: t("sign.app.registration.cancelled_retry_later"),
          )
        end

        private

        def cancel_sign_up_ticket
          if @sign_up_ticket.social_entry_method?
            SignAppUpSocialCancellation.call(cycle: @sign_up_ticket)
          else
            SignUpCancellation.call(cycle: @sign_up_ticket, actor_context: Actor.authn)
          end
        end

        def load_sign_up_ticket_for_destroy
          @sign_up_ticket = sign_up_flow_locator.current
          return if @sign_up_ticket

          sign_up_session_state.clear_all!
          redirect_to(
            "/",
            status: :see_other,
            notice: t("sign.app.registration.cancelled_retry_later"),
          )
        end

        def authorize_sign_up_cancellation!
          return if allowed_to?(:cancel?, sign_up_policy_context, with: SignUp::TicketPolicy)

          render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
        end

        def sign_up_surface = :app

        def sign_up_ticket_class = ClientSignUpFlow

        def sign_up_sequence_session_key = :sign_app_up_sequence_id
      end
    end
  end
end
