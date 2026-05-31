# frozen_string_literal: true

require "test_helper"
require "chain_seal"

class ChainSealTest < ActiveSupport::TestCase
  fixtures_none!

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @payload = {
      "event" => "auth.sign_in.succeeded",
      "metadata" => { "b" => 2, "a" => 1 },
      "result" => true,
    }
  end

  test "seals and verifies a payload with a temporary P-384 key" do
    seal = ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: @private_key)

    assert ChainSeal.verify(compact: seal.compact, payload: @payload, public_key: @private_key.public_key)
    assert_equal ChainSeal::GENESIS_PREVIOUS_HASH, seal.previous_hash
    assert_match(/\A\h{64}\z/, seal.block_hash)
  end

  test "canonical payload ignores hash key insertion order" do
    left = { "z" => 1, "a" => { "b" => 2, "a" => 1 } }
    right = { "a" => { "a" => 1, "b" => 2 }, "z" => 1 }

    left_seal = ChainSeal.seal(payload: left, kid: "test-kid", private_key: @private_key)
    right_seal = ChainSeal.seal(payload: right, kid: "test-kid", private_key: @private_key)

    assert_equal left_seal.block_hash, right_seal.block_hash
    assert ChainSeal.verify(compact: left_seal.compact, payload: right, public_key: @private_key.public_key)
  end

  test "compact string uses fixed fields and base64url raw signature" do
    seal = ChainSeal.seal(payload: @payload, kid: "kid_1", private_key: @private_key)
    parts = seal.compact.split("$", -1)

    assert_equal ["", "bc1", "jcs-rfc8785", "sha3-256", "es384"], parts.first(5)
    assert_equal 9, parts.size
    assert_equal "kid_1", parts.fetch(5)
    assert_equal 96, Base64.urlsafe_decode64(ChainSeal.pad_base64(parts.fetch(8))).bytesize
    assert_not_includes parts.fetch(8), "="
  end

  test "external json exposes compact fields" do
    seal = ChainSeal.seal(payload: @payload, kid: "kid-1", private_key: @private_key)

    assert_equal(
      {
        format: "bc1",
        canonicalization_alg: "jcs-rfc8785",
        hash_alg: "sha3-256",
        signature_alg: "es384",
        kid: "kid-1",
        previous_hash: ChainSeal::GENESIS_PREVIOUS_HASH,
        block_hash: seal.block_hash,
        signature: seal.signature,
      },
      seal.as_json,
    )
  end

  test "tampered payload fails verification" do
    seal = ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: @private_key)

    assert_raises(ChainSeal::VerificationError) do
      ChainSeal.verify(
        compact: seal.compact,
        payload: @payload.merge("result" => false),
        public_key: @private_key.public_key,
      )
    end
  end

  test "tampered compact fields fail parsing or verification" do
    seal = ChainSeal.seal(payload: @payload, kid: "test-kid", private_key: @private_key)

    assert_raises(ChainSeal::FormatError) { ChainSeal.parse(seal.compact.sub("sha3-256", "sha256")) }
    assert_raises(ChainSeal::FormatError) { ChainSeal.parse(seal.compact.sub("es384", "hs256")) }
    assert_raises(ChainSeal::FormatError) { ChainSeal.parse(seal.compact.sub("test-kid", "kid=value")) }
    assert_raises(ChainSeal::FormatError) { ChainSeal.parse(seal.compact.delete_prefix("$")) }
    assert_raises(ChainSeal::VerificationError) do
      ChainSeal.verify(
        compact: seal.compact.sub(seal.block_hash, "f" * 64),
        payload: @payload,
        public_key: @private_key.public_key,
      )
    end
  end

  test "rejects invalid hashes and key-value compact strings" do
    assert_raises(ChainSeal::FormatError) do
      ChainSeal.seal(payload: @payload, previous_hash: "0" * 63, kid: "kid", private_key: @private_key)
    end

    assert_raises(ChainSeal::FormatError) do
      ChainSeal.parse("$bc1$jcs-rfc8785$sha3-256$es384$kid=1$#{"0" * 64}$#{"1" * 64}$abc")
    end
  end

  test "rejects non P-384 keys" do
    wrong_key = OpenSSL::PKey::EC.generate("prime256v1")

    assert_raises(ChainSeal::FormatError) do
      ChainSeal.seal(payload: @payload, kid: "kid", private_key: wrong_key)
    end
  end
end
