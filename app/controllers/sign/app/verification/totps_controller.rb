# typed: false
# frozen_string_literal: true

class Sign::App::Verification::TotpsController < Sign::App::Verification::BaseController
  AUTHENTICATION_MODE = :private

  include Sign::VerificationTotpActions
end
