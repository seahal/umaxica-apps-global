# typed: false
# frozen_string_literal: true

class Sign::Org::Verification::PasskeysController < Sign::Org::Verification::BaseController
  include SignVerificationPasskeyActions

  AUTHENTICATION_MODE = :private
end
