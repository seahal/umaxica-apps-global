# typed: false
# frozen_string_literal: true

class Sign::App::Verification::PasskeysController < ::Sign::App::Verification::BaseController
  include SignVerificationPasskeyActions

  AUTHENTICATION_MODE = :private
end
