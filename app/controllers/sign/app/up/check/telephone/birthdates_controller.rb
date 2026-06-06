# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      module Check
        module Telephone
          class BirthdatesController < Sign::App::Up::Check::Email::BirthdatesController
            AUTHENTICATION_MODE = :guest

            private

            def sign_up_family = "telephone"
          end
        end
      end
    end
  end
end
