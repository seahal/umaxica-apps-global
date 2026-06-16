# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module Up
        module Check
          module Google
            class ConfirmationsController < ::Sign::App::ApplicationController
              include SignUpExplicitStepControllerSupport

              AUTHENTICATION_MODE = :guest

              def show
                return unless load_gate_context!(gate_for_show)

                render "sign/app/sign/up/check/social/confirmations/show"
              end

              def update
                return unless load_gate_context!(gate_for_update)
                return render plain: "social_signup_confirmation_required", status: :unprocessable_content unless
                  ActiveModel::Type::Boolean.new.cast(params[:confirm_new_social_identity])

                clear_current_requirement!
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              def sign_up_surface = :app

              def sign_up_ticket_class = ClientSignUpFlow

              def sign_up_sequence_session_key = :sign_app_up_sequence_id

              def sign_up_family = "google"

              def sign_up_step = :confirmation
            end
          end
        end
      end
    end
  end
end
