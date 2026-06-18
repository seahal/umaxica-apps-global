# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module Up
        module Check
          module Apple
            class BirthdatesController < ::Sign::App::ApplicationController
              include SignUpExplicitStepControllerSupport

              include SignUpSocialBirthdateSupport

              include SignUpSocialCheckBirthdateControllerSupport

              AUTHENTICATION_MODE = :open

              before_action :hide_sign_up_auth_navigation

              private

              def sign_up_family = "apple"
            end
          end
        end
      end
    end
  end
end
