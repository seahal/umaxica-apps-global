# typed: false
# frozen_string_literal: true

module OidcClientSecretResolver
  module_function

  def resolve(client_id)
    Rails.app.creds.option(credential_key_for(client_id))
  end

  def credential_key_for(client_id)
    :"OIDC_CLIENT_SECRETS_#{client_id.to_s.upcase}"
  end

  private_class_method :credential_key_for
end
