# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Google
            class BirthdatesController < ::Auth::App::ApplicationController
              include SignUpExplicitStepControllerSupport

              include SignUpSocialBirthdateSupport

              include SignUpSocialCheckBirthdateControllerSupport

              include ::SurfaceInertiaPage
              include AppSignUpCheckpointPage

              AUTHENTICATION_MODE = :open

              before_action :hide_sign_up_auth_navigation

              private

              def sign_up_family = "google"
            end
          end
        end
      end
    end
  end
end
