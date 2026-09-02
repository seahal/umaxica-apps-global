# typed: false
# frozen_string_literal: true

require "test_helper"

# A stored DBSC key that cannot yield a verification key is server-side state
# corruption, so the adapter has to name the failure rather than hand a nil key
# to the signature check.
class DbscRecordAdapterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a JWK that exposes only a verify key is accepted through that accessor" do
    verify_only = Object.new
    verify_only.define_singleton_method(:verify_key) { :the_verify_key }

    JWT::JWK.stub(:import, verify_only) do
      assert_equal(
        :the_verify_key,
        DbscRecordAdapter.verification_key_from_jwk({ "kty" => "OKP" }, source: "stored key"),
      )
    end
  end

  test "a JWK that exposes no verification key at all is refused by name" do
    opaque = Object.new

    error =
      JWT::JWK.stub(:import, opaque) do
        assert_raises(DbscRecordAdapter::PublicKeyError) do
          DbscRecordAdapter.verification_key_from_jwk({ "kty" => "OKP" }, source: "stored key")
        end
      end

    assert_match(/exposes no verification key/, error.message)
  end

  test "a symmetric key type is refused before any import is attempted" do
    error =
      assert_raises(DbscRecordAdapter::PublicKeyError) do
        DbscRecordAdapter.verification_key_from_jwk({ "kty" => "oct" }, source: "client key")
      end

    assert_match(/must be an asymmetric JWK/, error.message)
  end
end
