# typed: false
# frozen_string_literal: true

require "test_helper"

# Access-token verification runs on a token the caller supplies. A key that
# cannot be used at all -- a malformed key, or a claim of the wrong type -- must
# resolve to "no payload" and be recorded, never raise out of the authentication
# filter where it would answer a 500 instead of an unauthenticated response.
class SecurityJwtAuthAccessTokenCodecFailuresTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a key that cannot be used resolves to no payload and is recorded" do
    recorded = []
    unusable = ->(*, **) { raise OpenSSL::PKey::PKeyError, "unusable key" }

    Rails.logger.stub(:info, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
      JitSecurityJwtKeyring.stub(:parse_header, { "kid" => "any", "typ" => "at+jwt", "alg" => "ES384" }) do
        SecurityJwtAuthAccessTokenCodec.stub(:valid_header?, true) do
          JitSecurityJwtKeyring.stub(:public_key_for, unusable) do
            assert_nil SecurityJwtAuthAccessTokenCodec.decode_with_expiration(
              "a.b.c", host: "auth.app.localhost", resource_type: "client", verify_exp: true,
            )
          end
        end
      end
    end

    assert(recorded.any? { |line| line.include?("authentication.token.verification.error") })
  end

  test "a blank token or host resolves to no payload without touching the keyring" do
    assert_nil SecurityJwtAuthAccessTokenCodec.decode_with_expiration(
      "", host: "auth.app.localhost", verify_exp: true,
    )
    assert_nil SecurityJwtAuthAccessTokenCodec.decode_with_expiration(
      "a.b.c", host: "", verify_exp: true,
    )
  end
end
