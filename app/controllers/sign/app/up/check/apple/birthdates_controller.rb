# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      module Check
        module Apple
          class BirthdatesController < Sign::App::Up::Checkpoint::BirthdatesController
            include SignUpExplicitStepControllerSupport

            AUTHENTICATION_MODE = :guest

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

            def sign_up_family = "apple"

            def sign_up_step = :birthdate
          end
        end
      end
    end
  end
end
