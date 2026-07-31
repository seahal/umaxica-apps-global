# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationEntraClientAssertionAdapterTest < ActiveSupport::TestCase
  Connection = Data.define(:entra_client_id, :entra_credential_key)

  test "issues a short-lived PS256 assertion from a referenced certificate credential" do
    private_key = OpenSSL::PKey::RSA.generate(2048)
    certificate = self_signed_certificate(private_key)
    credential = {
      private_key_pem: private_key.to_pem,
      certificate_pem: certificate.to_pem,
    }
    connection = Connection.new(
      entra_client_id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      entra_credential_key: "ENTRA_TEST_CERTIFICATE",
    )
    now = Time.zone.local(2026, 7, 31, 12, 0, 0)

    assertion =
      travel_to(now) do
        Rails.app.creds.stub(:option, credential) do
          ExternalAuthentication::EntraClientAssertionAdapter.new(
            connection: connection,
            token_url: "https://login.microsoftonline.com/tenant/oauth2/v2.0/token",
            clock: -> { now },
          ).call
        end
      end
    payload, header =
      travel_to(now) do
      JWT.decode(assertion, private_key.public_key, true, algorithms: ["PS256"])
    end

    assert_equal "PS256", header.fetch("alg")
    assert_equal "JWT", header.fetch("typ")
    assert_predicate header.fetch("x5t#S256"), :present?
    assert_equal connection.entra_client_id, payload.fetch("iss")
    assert_equal connection.entra_client_id, payload.fetch("sub")
    assert_equal now.to_i + 300, payload.fetch("exp")
  end

  private

  def self_signed_certificate(private_key)
    certificate = OpenSSL::X509::Certificate.new
    certificate.serial = 1
    certificate.version = 2
    certificate.subject = OpenSSL::X509::Name.parse("/CN=entra-test")
    certificate.issuer = certificate.subject
    certificate.public_key = private_key.public_key
    certificate.not_before = 1.minute.ago
    certificate.not_after = 1.hour.from_now
    certificate.sign(private_key, OpenSSL::Digest::SHA256.new)
    certificate
  end
end
