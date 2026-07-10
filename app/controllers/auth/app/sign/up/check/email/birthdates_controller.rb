# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Email
            class BirthdatesController < ::Auth::App::ApplicationController
              include SignUpExplicitStepControllerSupport

              AUTHENTICATION_MODE = :open
              before_action :hide_sign_up_auth_navigation

              def show
                return unless load_gate_context!(gate_for_show)

                render_sign_up_checkpoint
              end

              def update
                return unless load_gate_context!(gate_for_update)

                clear_sign_up_birthdate_requirement
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def sign_up_surface = :app

              def sign_up_ticket_class = ClientSignUpFlow

              def sign_up_sequence_session_key = :auth_app_up_sequence_id

              def sign_up_family = "email"

              def sign_up_step = :birthdate

              def render_sign_up_checkpoint
                @sign_up_missing_requirements = sign_up_missing_requirements
                @sign_up_completed_requirements = @sign_up_ticket.completed_requirements
                @sign_up_pending_actor = sign_up_pending_actor

                render "auth/app/sign/up/checkpoints/show", status: :ok
              end
            end
          end
        end
      end
    end
  end
end
