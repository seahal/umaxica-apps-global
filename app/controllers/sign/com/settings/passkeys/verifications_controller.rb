# typed: false
# frozen_string_literal: true

class Sign::Com::Settings::Passkeys::VerificationsController < ::Sign::Com::Settings::PasskeysController
  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  skip_before_action :authorize_passkey_create!, only: :create, raise: false
  before_action :accept_com_passkey_ceremony_grant!, only: :create

  def create = verification
end
