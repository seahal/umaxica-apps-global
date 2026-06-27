# typed: false
# frozen_string_literal: true

class Auth::Com::Sign::Up::Check::Email::CancellationsController < ::Auth::Com::ApplicationController
  include SignUpExplicitStepControllerSupport

  AUTHENTICATION_MODE = :guest

  before_action :hide_sign_up_auth_navigation

  def create
    cancel_from_explicit_step
  end

  private

  def sign_up_surface = :com

  def sign_up_ticket_class = VisitorSignUpFlow

  def sign_up_sequence_session_key = :sign_com_up_sequence_id

  def sign_up_family = "email"

  def sign_up_step = :birthdate
end
