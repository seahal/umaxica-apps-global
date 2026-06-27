# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Telephone
            class PasskeysController < ::Auth::App::ApplicationController
              include CommonRedirect
              include SignWebauthn
              include SignPasskeyRegistrationFlow
              include SignUpSequenceControllerSupport
              include SignUpExplicitStepControllerSupport

              AUTHENTICATION_MODE = :guest

              before_action :hide_sign_up_auth_navigation
              before_action :load_sign_up_ticket
              before_action :load_sign_up_actor
              before_action :validate_sign_up_checkpoint_contact!
              before_action -> { authorize_sign_up_requirement!(:register_passkey?) }

              def show
                return unless load_gate_context!(gate_for_show)

                @sign_up_actor = sign_up_pending_actor
                @success_redirect_url = success_redirect_url
                render "auth/app/sign/up/checkpoint/passkeys/new"
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
                return finalize_sign_up_from_checkpoint!(json: true) if
                  result.success? && result.next_event == :finalize
                return render_sign_up_failure_result(result, json: true) unless result.success?

                render json: { status: "ok", redirect_url: success_redirect_url }, status: :created
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def success_redirect_url
                auth_app_sign_up_check_telephone_passcode_path(ri: params[:ri], pt: signed_pt_param)
              end

              def load_sign_up_actor
                @sign_up_actor = sign_up_pending_actor
                return if @sign_up_actor

                render json: { error: I18n.t("errors.messages.not_found", default: "Not found") },
                       status: :not_found
              end

              def passkey_registration_actor = @sign_up_actor

              def passkey_registration_passkeys = @sign_up_actor.client_passkeys

              def save_passkey_registration!(passkey)
                passkey.save!
                @sign_up_ticket.update!(pending_passkey_registration_id: passkey.id) if
                  @sign_up_ticket.has_attribute?(:pending_passkey_registration_id)
              end

              def sign_up_requirement_context
                SignUpRequirementContext.build(
                  surface: :app,
                  actor_authentication: sign_up_actor_authentication,
                  ticket: @sign_up_ticket,
                  requirement: :passkey,
                  pending_actor: @sign_up_actor,
                )
              rescue ArgumentError
                nil
              end

              def sign_up_family = "telephone"

              def sign_up_step = :passkey

              def sign_up_surface = :app

              def sign_up_ticket_class = ClientSignUpFlow

              def sign_up_sequence_session_key = :auth_app_up_sequence_id
            end
          end
        end
      end
    end
  end
end
