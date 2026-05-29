# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      module Checkpoint
        class PasscodesController < GuestController
          include Common::Redirect

          include Sign::PasscodeRegistrationFlow

          include Sign::Up::SequenceControllerSupport

          AUTHENTICATION_MODE = :guest

          before_action :load_sign_up_ticket
          before_action :load_sign_up_actor
          before_action :validate_sign_up_checkpoint_contact!
          before_action -> { authorize_sign_up_requirement!(:confirm_passcode?) }

          def new
            prepare_passcode_registration
          end

          def create
            return unless validate_sign_up_checkpoint_version!

            create_passcode_registration!

            result = perform_sign_up_event(
              :clear_requirement,
              payload: { requirement: :passcode, checkpoint_version: sign_up_checkpoint_version_param },
            )
            return finalize_sign_up_from_checkpoint! if result.success? && result.next_event == :finalize

            return render_sign_up_result(result) unless result.success?

            redirect_to(sign_app_up_checkpoint_path(ri: params[:ri], pt: signed_pt_param))
          rescue ActiveRecord::RecordInvalid => e
            @secret = e.record
            @raw_secret = session[passcode_registration_raw_session_key]
            render :new, status: :unprocessable_content
          end

          private

          def load_sign_up_actor
            @sign_up_actor = sign_up_pending_actor
            return if @sign_up_actor

            render plain: I18n.t("errors.messages.not_found", default: "Not found"), status: :not_found
          end

          def passcode_registration_secrets = @sign_up_actor.client_secrets

          def passcode_registration_secret_class = ClientSecret

          def passcode_registration_raw_session_key = :sign_app_up_passcode_raw

          def passcode_registration_param_key = :user_secret

          def passcode_registration_fallback_param_key = :client_secret

          def passcode_registration_create_secret!(raw_secret)
            secret = @sign_up_actor.client_secrets.new(
              passcode_registration_secret_params.merge(
                password: raw_secret,
                raw_secret: raw_secret,
                user_identity_secret_status_id: ClientSecretStatus::ACTIVE,
                user_secret_kind_id: ClientSecretKind::LOGIN,
              ),
            )
            secret.save!(validate: false)
            secret
          end

          def sign_up_requirement_context
            SignUp::RequirementContext.build(
              surface: :app,
              actor_authentication: sign_up_actor_authentication,
              ticket: @sign_up_ticket,
              requirement: :passcode,
              pending_actor: @sign_up_actor,
            )
          rescue ArgumentError
            nil
          end

          def sign_up_surface = :app

          def sign_up_ticket_class = ClientSignUpCycle

          def sign_up_sequence_session_key = :sign_app_up_sequence_id
        end
      end
    end
  end
end
