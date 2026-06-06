# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      module Check
        module Telephone
          class PasskeysController < Sign::Com::Up::Checkpoint::PasskeysController
            include SignUpExplicitStepControllerSupport

            AUTHENTICATION_MODE = :guest

            def show
              return unless load_gate_context!(gate_for_show)

              @sign_up_actor = sign_up_pending_actor
              @success_redirect_url = success_redirect_url
              render "sign/com/up/checkpoint/passkeys/new"
            end

            def create
              return unless load_gate_context!(gate_for_create)

              @sign_up_actor = sign_up_pending_actor
              render_passkey_registration_options
            end

            def update
              return unless load_gate_context!(gate_for_update)

              @sign_up_actor = sign_up_pending_actor
              return unless validate_sign_up_checkpoint_version!(json: true)
              return unless verify_and_create_passkey_registration!

              result = perform_sign_up_event(
                :clear_requirement,
                payload: { requirement: :passkey, checkpoint_version: sign_up_checkpoint_version_param },
              )
              return finalize_sign_up_from_checkpoint!(json: true) if result.success? && result.next_event == :finalize
              return render_sign_up_failure_result(result, json: true) unless result.success?

              render json: { status: "ok", redirect_url: success_redirect_url }, status: :created
            end

            def destroy
              cancel_from_explicit_step
            end

            private

            def success_redirect_url
              sign_com_up_check_telephone_passcode_path(ri: params[:ri], pt: signed_pt_param)
            end

            def sign_up_family = "telephone"

            def sign_up_step = :passkey
          end
        end
      end
    end
  end
end
