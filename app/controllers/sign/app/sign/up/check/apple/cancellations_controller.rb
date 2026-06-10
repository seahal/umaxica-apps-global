# typed: false
# frozen_string_literal: true

# Dedicated cancellation endpoint for the Apple sign-up check step.
# Inherits the Apple birthdate check controller to reuse its explicit-step
# context (sign_up_family, gate setup) and the shared
# SignUpExplicitStepControllerSupport#cancel_from_explicit_step behavior.
class Sign::App::Sign::Up::Check::Apple::CancellationsController < ::Sign::App::Up::Check::Apple::BirthdatesController
  AUTHENTICATION_MODE = :guest

  def create
    cancel_from_explicit_step
  end
end
