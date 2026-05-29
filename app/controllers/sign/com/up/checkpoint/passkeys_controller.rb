# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      module Checkpoint
        class PasskeysController < GuestController
          include Common::Redirect

          include Sign::PasskeyRegistrationFlow

          include Sign::Up::SequenceControllerSupport

          AUTHENTICATION_MODE = :guest

          before_action :load_sign_up_ticket
          before_action :load_sign_up_actor
          before_action :validate_sign_up_checkpoint_contact!
          before_action -> { authorize_sign_up_requirement!(:register_passkey?) }

          def new
            @success_redirect_url = success_redirect_url
          end

          def begin
            render_passkey_registration_options
          end

          def create
            return unless validate_sign_up_checkpoint_version!(json: true)
            return unless verify_and_create_passkey_registration!

            result = perform_sign_up_event(
              :clear_requirement,
              payload: { requirement: :passkey, checkpoint_version: sign_up_checkpoint_version_param },
            )
            return finalize_sign_up_from_checkpoint!(json: true) if result.success? && result.next_event == :finalize
            return render_sign_up_failure_result(result, json: true) unless result.success?

            render json: {
              status: "ok",
              redirect_url: success_redirect_url,
            }, status: :created
          end

          private

          def load_sign_up_actor
            @sign_up_actor = sign_up_pending_actor
            return if @sign_up_actor

            render json: { error: I18n.t("errors.messages.not_found", default: "Not found") },
                   status: :not_found
          end

          def passkey_registration_actor = @sign_up_actor

          def passkey_registration_passkeys = @sign_up_actor.visitor_passkeys

          def save_passkey_registration!(passkey)
            passkey.valid?
            passkey.save!(validate: false)
            @sign_up_ticket.update!(pending_passkey_registration_id: passkey.id) if
              @sign_up_ticket.has_attribute?(:pending_passkey_registration_id)
          end

          def success_redirect_url
            sign_com_up_checkpoint_path(ri: params[:ri], pt: signed_pt_param)
          end

          def sign_up_requirement_context
            SignUp::RequirementContext.build(
              surface: :com,
              actor_authentication: sign_up_actor_authentication,
              ticket: @sign_up_ticket,
              requirement: :passkey,
              pending_actor: @sign_up_actor,
            )
          rescue ArgumentError
            nil
          end

          def sign_up_surface = :com

          def sign_up_ticket_class = VisitorSignUpCycle

          def sign_up_sequence_session_key = :sign_com_up_sequence_id
        end
      end
    end
  end
end
