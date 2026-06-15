# typed: false
# frozen_string_literal: true

# Dedicated cancellation endpoint for the telephone sign-up check step.
# Inherits the telephone birthdate check controller to reuse its explicit-step
# context (sign_up_family, gate setup) and the shared
# SignUpExplicitStepControllerSupport#cancel_from_explicit_step behavior.
class Sign::App::Sign::Up::Check::Telephone::CancellationsController < ::Sign::App::Sign::Up::Check::Telephone::BirthdatesController
  AUTHENTICATION_MODE = :guest

  def create
    cancel_from_explicit_step
  end
end
