# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module Up
        module Check
          module Telephone
            class BirthdatesController < ::Auth::Com::Sign::Up::Check::Email::BirthdatesController
              AUTHENTICATION_MODE = :guest

              private

              def sign_up_family = "telephone"
            end
          end
        end
      end
    end
  end
end
