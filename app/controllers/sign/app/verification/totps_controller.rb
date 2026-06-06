# typed: false
# frozen_string_literal: true

class Sign::App::Verification::TotpsController < ::Sign::App::Verification::BaseController
  include SignVerificationTotpActions

  AUTHENTICATION_MODE = :private
end
