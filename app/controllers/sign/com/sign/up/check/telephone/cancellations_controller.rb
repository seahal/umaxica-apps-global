# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::Up::Check::Telephone::CancellationsController < ::Sign::Com::ApplicationController
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

  def sign_up_family = "telephone"

  def sign_up_step = :birthdate
end
