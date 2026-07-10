# typed: false
# frozen_string_literal: true

class Auth::App::Verification::TotpsController < ::Auth::App::Verification::BaseController
  include SignVerificationTotpActions

  AUTHENTICATION_MODE = :private
end
