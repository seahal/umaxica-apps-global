# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module Up
        module Check
          module Google
            class ConfirmationsController < ::Sign::App::Sign::Up::Check::Apple::ConfirmationsController
              AUTHENTICATION_MODE = :guest

              private

              def sign_up_family = "google"
            end
          end
        end
      end
    end
  end
end
