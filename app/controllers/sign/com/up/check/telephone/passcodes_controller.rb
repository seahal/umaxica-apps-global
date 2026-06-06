# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      module Check
        module Telephone
          class PasscodesController < Sign::Com::Up::Checkpoint::PasscodesController
            include SignUpExplicitStepControllerSupport

            AUTHENTICATION_MODE = :guest

            def show
              return unless load_gate_context!(gate_for_show)

              @sign_up_actor = sign_up_pending_actor
              prepare_passcode_registration
              render "sign/com/up/checkpoint/passcodes/new"
            end

            def update
              return unless load_gate_context!(gate_for_update)

              @sign_up_actor = sign_up_pending_actor
              return unless validate_sign_up_checkpoint_version!

              create_passcode_registration!
              result = perform_sign_up_event(
                :clear_requirement,
                payload: { requirement: :passcode, checkpoint_version: sign_up_checkpoint_version_param },
              )
              return finalize_sign_up_from_checkpoint! if result.success? && result.next_event == :finalize
              return render_sign_up_result(result) unless result.success?

              redirect_to(sign_com_up_check_telephone_birthdate_path(ri: params[:ri], pt: signed_pt_param))
            rescue ActiveRecord::RecordInvalid => e
              @secret_credential = e.record
              @raw_secret_credential = session[passcode_registration_raw_session_key]
              render "sign/com/up/checkpoint/passcodes/new", status: :unprocessable_content
            end

            def destroy
              cancel_from_explicit_step
            end

            private

            def sign_up_family = "telephone"

            def sign_up_step = :passcode
          end
        end
      end
    end
  end
end
