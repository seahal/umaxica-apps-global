# typed: false
# frozen_string_literal: true

class Auth::App::Verification::PasskeysController < ::Auth::App::Verification::BaseController
  include SignVerificationPasskeyActions

  AUTHENTICATION_MODE = :private
end
