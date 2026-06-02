# typed: false
# frozen_string_literal: true

module Sign::Org
  class SignUpsController < Sign::Org::ApplicationController
    AUTHENTICATION_MODE = :guest

    def new
      @google_signup_enabled = Sign::Social::TemporarySignupGate.signup_enabled?
    end
  end
end
