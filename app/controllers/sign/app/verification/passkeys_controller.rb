# typed: false
# frozen_string_literal: true

class Sign::App::Verification::PasskeysController < Sign::App::Verification::BaseController
  AUTHENTICATION_MODE = :private

  include Sign::VerificationPasskeyActions
end
