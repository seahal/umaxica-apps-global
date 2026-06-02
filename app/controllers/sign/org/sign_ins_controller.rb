# typed: false
# frozen_string_literal: true

module Sign::Org
  class SignInsController < Sign::Org::ApplicationController
    AUTHENTICATION_MODE = :guest

    def new
      @google_signin_enabled = Sign::Social::OrgGoogleSigninGate.enabled?
    end
  end
end
