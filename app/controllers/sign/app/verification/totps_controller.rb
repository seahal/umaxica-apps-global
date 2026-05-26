# typed: false
# frozen_string_literal: true

class Sign::App::Verification::TotpsController < Sign::App::Verification::BaseController
  include Sign::VerificationTotpActions

  AUTHENTICATION_MODE = :private
end
