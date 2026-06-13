# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Up
      module Check
        module Google
          class BirthdatesController < ::Sign::App::ApplicationController
            include SignUpExplicitStepControllerSupport

            include SignUpSocialBirthdateSupport

            include SignUpSocialCheckBirthdateControllerSupport

            AUTHENTICATION_MODE = :guest

            before_action :hide_sign_up_auth_navigation

            private

            def sign_up_family = "google"
          end
        end
      end
    end
  end
end
