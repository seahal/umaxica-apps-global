# typed: false
# frozen_string_literal: true

class ExternalAuthenticationAppleCredentialRevocationRequestIssuer
  def self.call(client:, refresh_token:, reason:)
    ClientAppleCredentialRevocation.create_for!(
      client: client,
      refresh_token: refresh_token,
      reason: reason,
    )
  end
end
