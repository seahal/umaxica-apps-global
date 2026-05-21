# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      module Checkpoint
        class PasscodesController < GuestController
          include Common::Redirect
          include Sign::PasscodeRegistrationFlow
          include Sign::Up::SequenceControllerSupport

          before_action :load_sign_up_ticket
          before_action :load_sign_up_actor
          before_action :validate_sign_up_checkpoint_contact!
          before_action -> { authorize_sign_up_requirement!(:confirm_passcode?) }

          def new
            prepare_passcode_registration
          end

          def create
            create_passcode_registration!

            result = perform_sign_up_event(:clear_requirement, payload: { requirement: :passcode })
            return finalize_sign_up_from_checkpoint! if result.success? && result.next_event == :finalize

            return render_sign_up_result(result) unless result.success?

            redirect_to(sign_com_up_checkpoint_path(ri: params[:ri], rt: params[:rt].presence))
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

          def passcode_registration_secrets = @sign_up_actor.visitor_secrets

          def passcode_registration_secret_class = VisitorSecret

          def passcode_registration_raw_session_key = :sign_com_up_passcode_raw

          def passcode_registration_param_key = :visitor_secret

          def passcode_registration_create_secret!(raw_secret)
            secret = @sign_up_actor.visitor_secrets.new(
              passcode_registration_secret_params.merge(
                password: raw_secret,
                raw_secret: raw_secret,
                visitor_secret_status_id: VisitorSecretStatus::ACTIVE,
                visitor_secret_kind_id: VisitorSecretKind::LOGIN,
              ),
            )
            secret.save!(validate: false)
            secret
          end

          def sign_up_requirement_context
            SignUp::RequirementContext.build(
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

          def sign_up_ticket_class = VisitorSignUpCycle

          def sign_up_sequence_session_key = :sign_com_up_sequence_id
        end
      end
    end
  end
end
