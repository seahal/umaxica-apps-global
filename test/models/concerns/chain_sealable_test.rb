# frozen_string_literal: true

require "test_helper"
require "chain_seal"

class ChainSealableTest < ActiveSupport::TestCase
  fixtures_none!

  class TestRecord
    include ActiveModel::Model
    include ChainSealable

    attr_accessor :event, :metadata, :seal_value

    chain_seal_column :seal_value
    chain_seal_payload_method :audit_payload

    def audit_payload
      { "event" => event, "metadata" => metadata }
    end
  end

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    TestRecord.chain_seal_key_provider(lambda { |_record| { kid: "concern-kid", private_key: @private_key } })
  end

  teardown do
    TestRecord.chain_seal_key_provider(nil)
  end

  test "build_chain_seal explicitly stores compact seal on configured column" do
    record = TestRecord.new(event: "auth.sign_in.succeeded", metadata: { "a" => 1 })

    seal = record.build_chain_seal!

    assert_equal seal.compact, record.seal_value
    assert ChainSeal.verify(
      compact: record.seal_value,
      payload: record.audit_payload,
      public_key: @private_key.public_key,
    )
  end

  test "verify_chain_seal verifies configured payload and column" do
    record = TestRecord.new(event: "auth.sign_in.succeeded", metadata: { "a" => 1 })
    record.build_chain_seal!

    assert record.verify_chain_seal!(public_key: @private_key.public_key)
  end

  test "verify_chain_seal fails when payload changes" do
    record = TestRecord.new(event: "auth.sign_in.succeeded", metadata: { "a" => 1 })
    record.build_chain_seal!
    record.metadata = { "a" => 2 }

    assert_raises(ChainSeal::VerificationError) { record.verify_chain_seal!(public_key: @private_key.public_key) }
  end

  test "chain_seal_json exports parsed compact fields" do
    record = TestRecord.new(event: "auth.sign_in.succeeded", metadata: { "a" => 1 })
    seal = record.build_chain_seal!

    assert_equal seal.as_json, record.chain_seal_json
  end

  test "including the concern does not install callbacks or mutate automatically" do
    record = TestRecord.new(event: "auth.sign_in.succeeded", metadata: { "a" => 1 })

    assert_nil record.seal_value
    assert_empty TestRecord._save_callbacks if TestRecord.respond_to?(:_save_callbacks)
  end

  test "missing key provider fails clearly" do
    TestRecord.chain_seal_key_provider(nil)
    record = TestRecord.new(event: "auth.sign_in.succeeded", metadata: { "a" => 1 })

    assert_raises(ChainSeal::FormatError) { record.build_chain_seal! }
  end
end
