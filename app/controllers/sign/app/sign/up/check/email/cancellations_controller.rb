# typed: false
# frozen_string_literal: true

class Sign::App::Sign::Up::Check::Email::CancellationsController < ::Sign::App::Up::Check::Email::BirthdatesController
  AUTHENTICATION_MODE = :guest

  def create
    cancel_from_explicit_step
  end
end
