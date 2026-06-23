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

  class DefaultsTestRecord
    include ActiveModel::Model
    include ChainSealable

    attr_accessor :chain_seal_payload, :chain_seal
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

  test "default chain_seal_payload_method_name when not configured" do
    assert_equal :chain_seal_payload, DefaultsTestRecord.chain_seal_payload_method_name
  end

  test "default chain_seal_column_name when not configured" do
    assert_equal :chain_seal, DefaultsTestRecord.chain_seal_column_name
  end

  test "default chain_seal_key_provider_object when not configured" do
    assert_nil DefaultsTestRecord.chain_seal_key_provider_object
  end

  test "chain_seal_key_material uses provider directly when it does not respond to call" do
    TestRecord.chain_seal_key_provider({ kid: "static-kid", private_key: @private_key })

    record = TestRecord.new(event: "auth.sign_in.succeeded", metadata: { "a" => 1 })
    result = record.build_chain_seal!
    seal = ChainSeal.verify(
      compact: result.compact,
      payload: record.audit_payload,
      public_key: @private_key.public_key,
    )

    assert seal
  ensure
    TestRecord.chain_seal_key_provider(lambda { |_record| { kid: "concern-kid", private_key: @private_key } })
  end

  test "chain_seal_key_provider accepts a block that receives the record" do
    TestRecord.chain_seal_key_provider do |record|
      { kid: "block-kid-#{record.event}", private_key: @private_key }
    end
    record = TestRecord.new(event: "auth.sign_in.succeeded", metadata: { "a" => 1 })
    seal = record.build_chain_seal!

    assert_equal "block-kid-auth.sign_in.succeeded", ChainSeal.parse(seal.compact).kid
    assert ChainSeal.verify(
      compact: seal.compact,
      payload: record.audit_payload,
      public_key: @private_key.public_key,
    )
  ensure
    TestRecord.chain_seal_key_provider(lambda { |_record| { kid: "concern-kid", private_key: @private_key } })
  end

  test "build_chain_seal raises when the configured payload method is missing" do
    klass =
      Class.new do
        include ActiveModel::Model
        include ChainSealable

        chain_seal_payload_method :missing_payload
      end
    klass.chain_seal_key_provider({ kid: "static-kid", private_key: @private_key })

    assert_raises(ChainSeal::FormatError) { klass.new.build_chain_seal! }
  end

  test "build_chain_seal returns the seal without storing when the column writer is absent" do
    klass =
      Class.new do
        include ActiveModel::Model
        include ChainSealable

        attr_accessor :event

        chain_seal_column :seal_value
        chain_seal_payload_method :audit_payload

        def audit_payload
          { "event" => event }
        end
      end
    klass.chain_seal_key_provider({ kid: "static-kid", private_key: @private_key })
    record = klass.new(event: "test.event")

    seal = record.build_chain_seal!

    assert seal
    assert_not_respond_to record, :seal_value=
  end
end
