# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module Up
        module Check
          module Email
            class BirthdatesController < ::Sign::App::ApplicationController
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

              def sign_up_sequence_session_key = :sign_app_up_sequence_id

              def sign_up_family = "email"

              def sign_up_step = :birthdate

              def render_sign_up_checkpoint
                @sign_up_missing_requirements = sign_up_missing_requirements
                @sign_up_completed_requirements = @sign_up_ticket.completed_requirements
                @sign_up_pending_actor = sign_up_pending_actor

                render "sign/app/sign/up/checkpoints/show", status: :ok
              end

              def finalize_sign_up_from_checkpoint!(json: false)
                return super if json

                render(
                  "sign/shared/email_signup_completion",
                  locals: {
                    completion_url: completion_acme_app_sign_up_email_url(
                      ri: params[:ri],
                      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
                    ),
                    completion_token: email_signup_completion_token!,
                    completion_actor_token: email_signup_completion_actor_token!,
                    completion_email_token: email_signup_completion_email_token!,
                    pt: signed_pt_param,
                    ri: params[:ri],
                  },
                  layout: false,
                )
              end

              def email_signup_completion_token!
                @sign_up_ticket.signed_id(purpose: :email_signup_completion, expires_in: 15.minutes)
              end

              def email_signup_completion_actor_token!
                actor = Client.find_by(id: @sign_up_ticket.principal_id)
                raise IdentityCeremonyContract::Error, "email actor is required" unless actor

                actor.signed_id(purpose: :email_signup_completion, expires_in: 15.minutes)
              end

              def email_signup_completion_email_token!
                email = ClientEmail.find_by(id: @sign_up_ticket.pending_contact_id)
                raise IdentityCeremonyContract::Error, "email candidate is required" unless email

                email.signed_id(purpose: :email_signup_completion, expires_in: 15.minutes)
              end
            end
          end
        end
      end
    end
  end
end
