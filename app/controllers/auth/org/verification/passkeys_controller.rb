# typed: false
# frozen_string_literal: true

class Auth::Org::Verification::PasskeysController < ::Auth::Org::Verification::BaseController
  include SignVerificationPasskeyActions

  AUTHENTICATION_MODE = :private
end
