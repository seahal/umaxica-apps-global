# typed: false
# frozen_string_literal: true

class Sign::App::Sign::Up::Check::Google::CancellationsController < ::Sign::App::ApplicationController
  include SignUpExplicitStepControllerSupport

  AUTHENTICATION_MODE = :guest

  before_action :hide_sign_up_auth_navigation

  def create
    cancel_from_explicit_step
  end

  private

  def sign_up_surface = :app

  def sign_up_ticket_class = ClientSignUpFlow

  def sign_up_sequence_session_key = :sign_app_up_sequence_id

  def sign_up_family = "google"

  def sign_up_step = :birthdate
end
