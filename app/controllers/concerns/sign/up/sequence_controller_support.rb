# typed: false
# frozen_string_literal: true

module Sign
  module Up
    module SequenceControllerSupport
      extend ActiveSupport::Concern

      private

      def load_sign_up_ticket
        @sign_up_ticket = sign_up_cycle_locator.current
        return if @sign_up_ticket

        render plain: I18n.t("errors.messages.not_found", default: "Not found"), status: :not_found
      end

      def authorize_sign_up_participant!(rule)
        return if performed?

        context = sign_up_policy_context
        return if allowed_to?(rule, context, with: SignUp::ParticipantPolicy)

        render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
      end

      def authorize_sign_up_requirement!(rule)
        return if performed?

        context = sign_up_requirement_context
        return if context && allowed_to?(rule, context, with: SignUp::RequirementPolicy)

        render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
      end

      def sign_up_policy_context
        SignUp::PolicyContext.build(
          surface: sign_up_surface,
          actor_authentication: sign_up_actor_authentication,
          ticket: @sign_up_ticket,
        )
      end

      def sign_up_requirement_context
        requirement = params[:requirement].presence || params.dig(:sign_up, :requirement).presence
        return if requirement.blank?

        SignUp::RequirementContext.build(
          surface: sign_up_surface,
          actor_authentication: sign_up_actor_authentication,
          ticket: @sign_up_ticket,
          requirement: requirement,
          pending_actor: sign_up_pending_actor,
        )
      rescue ArgumentError
        nil
      end

      def run_sign_up_event(event, payload: {})
        return if performed?

        result =
          sign_up_ticket_record_class.connected_to(role: :writing) do
            SignUp::StateMachine.call(
              ticket: @sign_up_ticket,
              event: event,
              actor_context: sign_up_actor_authentication,
              payload: payload,
            )
          end

        render_sign_up_result(result)
      end

      def render_sign_up_result(result)
        status =
          case result.status
          when :ok, :advanced, :completed, :sign_in_handoff_accepted
            :ok
          when :blocked, :unauthorized
            :forbidden
          when :expired
            :gone
          else
            :unprocessable_content
          end

        render plain: result.status.to_s, status: status
      end

      def persist_sign_up_birthdate_requirement
        return true unless sign_up_requirement_param == "birthdate"

        actor = sign_up_pending_actor
        unless actor
          render plain: I18n.t("errors.messages.not_found", default: "Not found"), status: :not_found
          return false
        end

        actor.birthdate = sign_up_birthdate_param
        unless actor.save
          render plain: actor.errors.full_messages.to_sentence, status: :unprocessable_content
          return false
        end

        true
      end

      def sign_up_ticket_public_id
        params[:sid].presence || session[sign_up_sequence_session_key].presence
      end

      def sign_up_requirement_param
        (params[:requirement].presence || params.dig(:sign_up, :requirement).presence).to_s
      end

      def sign_up_birthdate_param
        params[:birthdate].presence ||
          params.dig(:sign_up, :birthdate).presence ||
          params.dig(:client, :birthdate).presence ||
          params.dig(:visitor, :birthdate).presence
      end

      def sign_up_actor_authentication
        Actor::Authentication.new(
          login_public_id: Actor.authentication.login_public_id,
          access_claims: Actor.authentication.access_claims,
          acr: Actor.authentication.acr,
          amr: Actor.authentication.amr,
          actor_type: Actor.authentication.actor_type,
          actor_id: Actor.authentication.actor_id,
          restricted: Actor.authentication.restricted?,
          active_sign_sequence_id: @sign_up_ticket&.public_id,
        )
      end

      def sign_up_cycle_locator
        SignUp::CycleLocator.new(session, surface: sign_up_surface, cycle_class: sign_up_ticket_class)
      end

      def sign_up_pending_actor
        return if @sign_up_ticket&.principal_id.blank?

        case @sign_up_ticket
        when ClientSignUpCycle
          Client.find_by(id: @sign_up_ticket.principal_id)
        when VisitorSignUpCycle
          Visitor.find_by(id: @sign_up_ticket.principal_id)
        end
      end

      def sign_up_ticket_record_class
        case @sign_up_ticket
        when ClientSignUpCycle
          AppTicketRecord
        when VisitorSignUpCycle
          ComTicketRecord
        else
          @sign_up_ticket.class
        end
      end
    end
  end
end
