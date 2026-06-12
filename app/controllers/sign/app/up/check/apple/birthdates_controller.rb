# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      module Check
        module Apple
          class BirthdatesController < ::Sign::App::ApplicationController
            include SignUpSocialCheckBirthdateControllerSupport

            private

            def sign_up_family = "apple"
          end
        end
      end
    end
  end
end
