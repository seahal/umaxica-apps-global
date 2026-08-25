# typed: false
# frozen_string_literal: true

require "test_helper"
require "argon2"

# Guards the Argon2id cost parameters that SecretCredential digests are produced
# with. ActiveModel::SecurePassword::Argon2Password calls
# Argon2::Password.create without passing a profile, so there is no application
# hook to pin the parameters: the gem default *is* the production setting. A gem
# upgrade could therefore weaken hashing silently. These assertions fail if that
# default moves.
#
# Note on the threat model: the only has_secure_password call site is
# SecretCredential, which hashes SecureRandom.base58(32) values (~187 bits of
# entropy), not human-chosen passwords. Brute-force resistance comes from the
# input entropy, so the OWASP 100-300 ms guidance for password hashing does not
# apply here and these parameters are not a security floor to raise. They are
# pinned to keep digests reproducible and to make any change deliberate.
class Argon2ParametersTest < ActiveSupport::TestCase
  EXPECTED_PROFILE = { t_cost: 3, m_cost: 16, p_cost: 4 }.freeze

  # m_cost is a power-of-two exponent: 2**16 KiB == 65536 KiB == 64 MiB.
  EXPECTED_DIGEST_PREFIX = /\A\$argon2id\$v=19\$m=65536,t=3,p=4\$/

  test "the RFC 9106 low-memory profile still has the pinned cost parameters" do
    assert_equal EXPECTED_PROFILE, Argon2::Profiles[:rfc_9106_low_memory]
  end

  test "Argon2::Password.create defaults to the pinned cost parameters" do
    # Deliberately calls the gem directly rather than going through
    # has_secure_password: config/environments/test.rb sets
    # ActiveModel::SecurePassword.min_cost, which switches the Rails adapter to
    # the :unsafe_cheapest profile, so a digest built through a model would not
    # reflect production parameters.
    digest = Argon2::Password.create("argon2-parameter-guard")

    assert_match EXPECTED_DIGEST_PREFIX, digest
  end

  test "the Rails adapter takes the gem default instead of a configured profile" do
    source =
      ActiveModel::SecurePassword::Argon2Password
        .instance_method(:hash_password)
        .source_location
        .then { |path, _line| File.read(path) }

    assert_includes source, "::Argon2::Password.create(unencrypted_password)",
                    "Argon2Password#hash_password no longer relies on the gem default; " \
                    "if it now accepts a profile, pin the parameters there and update this test."
  end
end
