# typed: false
# frozen_string_literal: true

class Sign::Org::Verification::PasskeysController < Sign::Org::Verification::BaseController
  AUTHENTICATION_MODE = :private

  include Sign::VerificationPasskeyActions
end
