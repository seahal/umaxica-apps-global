# typed: false
# frozen_string_literal: true

class Sign::App::Verification::PasskeysController < Sign::App::Verification::BaseController
  include Sign::VerificationPasskeyActions

  AUTHENTICATION_MODE = :private
end
