# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      module Check
        module Google
          class ConfirmationsController < Sign::App::Up::Check::Apple::ConfirmationsController
            AUTHENTICATION_MODE = :guest

            private

            def sign_up_family = "google"
          end
        end
      end
    end
  end
end
