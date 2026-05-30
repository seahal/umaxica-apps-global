# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      module Checkpoint
        class PasscodesController < Sign::App::ApplicationController
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
            @secret_credential = e.record
            @raw_secret_credential = session[passcode_registration_raw_session_key]
            render :new, status: :unprocessable_content
          end

          private

          def load_sign_up_actor
            @sign_up_actor = sign_up_pending_actor
            return if @sign_up_actor

            render plain: I18n.t("errors.messages.not_found", default: "Not found"), status: :not_found
          end

          def passcode_registration_secret_credentials = @sign_up_actor.client_secret_credentials

          def passcode_registration_secret_credential_class = ClientSecretCredential

          def passcode_registration_raw_session_key = :sign_app_up_passcode_raw

          def passcode_registration_param_key = :user_secret_credential

          def passcode_registration_fallback_param_key = :client_secret

          def passcode_registration_create_secret_credential!(raw_secret_credential)
            secret_credential = @sign_up_actor.client_secret_credentials.new(
              passcode_registration_secret_credential_params.merge(
                password: raw_secret_credential,
                raw_secret_credential: raw_secret_credential,
                user_identity_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
                user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
              ),
            )
            secret_credential.save!(validate: false)
            secret_credential
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

          def sign_up_ticket_class = ClientSignUpFlow

          def sign_up_sequence_session_key = :sign_app_up_sequence_id
        end
      end
    end
  end
end
