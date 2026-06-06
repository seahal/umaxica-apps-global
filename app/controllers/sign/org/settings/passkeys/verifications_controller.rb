# typed: false
# frozen_string_literal: true

class Sign::Org::Settings::Passkeys::VerificationsController < ::Sign::Org::Settings::PasskeysController
  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  skip_before_action :authorize_passkey_create!, only: :create, raise: false
  before_action :accept_org_passkey_ceremony_grant!, only: :create

  def create = verification
end
