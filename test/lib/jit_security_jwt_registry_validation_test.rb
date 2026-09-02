# typed: false
# frozen_string_literal: true

require "test_helper"

# The signing registry refuses at boot rather than at first use. An issuer whose
# active key id has been revoked would otherwise mint tokens with a key
# verifiers are told to reject, so the registry names the issuer and the key and
# stops.
class JitSecurityJwtRegistryValidationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  Record = Struct.new(:id, :current_kid, :keys, :revoked_kids, keyword_init: true)

  test "an issuer whose active key is revoked is refused by name" do
    record = Record.new(
      id: "surface:SIGN_APP",
      current_kid: "kid-1",
      keys: { "kid-1" => "key-material" },
      revoked_kids: ["kid-1"],
    )

    error =
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        JitSecurityJwtRegistry.send(:validate_active_key!, record)
      end

    assert_match(/is revoked/, error.message)
  end

  test "an issuer whose active key is absent is refused by name" do
    record = Record.new(
      id: "surface:SIGN_APP",
      current_kid: "kid-2",
      keys: { "kid-1" => "key-material" },
      revoked_kids: [],
    )

    error =
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        JitSecurityJwtRegistry.send(:validate_active_key!, record)
      end

    assert_match(/is missing/, error.message)
  end
end
