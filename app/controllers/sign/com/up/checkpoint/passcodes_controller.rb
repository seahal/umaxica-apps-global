# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      module Checkpoint
        class PasscodesController < ::Sign::Com::ApplicationController
          include CommonRedirect

          include SignPasscodeRegistrationFlow

          include SignUpSequenceControllerSupport

          AUTHENTICATION_MODE = :guest

          before_action :hide_sign_up_auth_navigation
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

            redirect_to(sign_com_sign_up_check_path(ri: params[:ri], pt: signed_pt_param))
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

          def passcode_registration_secret_credentials = @sign_up_actor.visitor_secret_credentials

          def passcode_registration_secret_credential_class = VisitorSecretCredential

          def passcode_registration_raw_session_key = :sign_com_up_passcode_raw

          def passcode_registration_param_key = :visitor_secret_credential

          def passcode_registration_create_secret_credential!(raw_secret_credential)
            secret_credential = @sign_up_actor.visitor_secret_credentials.new(
              passcode_registration_secret_credential_params.merge(
                password: raw_secret_credential,
                raw_secret_credential: raw_secret_credential,
                visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
                visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
              ),
            )
            # save! with validate: false bypasses all model validators (including
            # RecoveryIdentityRequiredValidator, which fires before the telephone reaches
            # VERIFIED_WITH_SIGN_UP) while still running before_create callbacks such as
            # generate_public_id. All attribute data comes from controlled system generation,
            # so skipping model-level validation here is safe.
            secret_credential.save!(validate: false)
            secret_credential
          end

          def sign_up_requirement_context
            SignUpRequirementContext.build(
              surface: :com,
              actor_authentication: sign_up_actor_authentication,
              ticket: @sign_up_ticket,
              requirement: :passcode,
              pending_actor: @sign_up_actor,
            )
          rescue ArgumentError
            nil
          end

          def sign_up_surface = :com

          def sign_up_ticket_class = VisitorSignUpFlow

          def sign_up_sequence_session_key = :sign_com_up_sequence_id
        end
      end
    end
  end
end
