# typed: false
# frozen_string_literal: true

class Sign::Org::Settings::Passkeys::OptionsController < ::Sign::Org::Settings::PasskeysController
  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  skip_before_action :authorize_passkey_create!, only: :create, raise: false
  before_action :accept_org_passkey_ceremony_grant!, only: :create
  before_action :verify_settings_passkey_turnstile!, only: :create

  def create = options
end
