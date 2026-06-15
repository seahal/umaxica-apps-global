# typed: false
# frozen_string_literal: true

# Dedicated cancellation endpoint for the email sign-up check step (com surface).
# Inherits the email birthdate check controller to reuse its explicit-step
# context (sign_up_family, gate setup) and the shared
# SignUpExplicitStepControllerSupport#cancel_from_explicit_step behavior.
class Sign::Com::Sign::Up::Check::Email::CancellationsController < ::Sign::Com::Sign::Up::Check::Email::BirthdatesController
  AUTHENTICATION_MODE = :guest

  def create
    cancel_from_explicit_step
  end
end
