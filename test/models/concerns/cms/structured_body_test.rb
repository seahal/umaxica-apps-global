# typed: false
# frozen_string_literal: true

require "test_helper"

class CmsStructuredBodyTest < ActiveSupport::TestCase
  test "canonical JSON recursively sorts object keys while preserving array order" do
    body = { "z" => 1, "a" => { "y" => 2, "x" => [{ "b" => 1, "a" => 2 }, 3] } }

    assert_equal '{"a":{"x":[{"a":2,"b":1},3],"y":2},"z":1}', Cms::StructuredBody.canonical_json(body)
  end

  test "digest is deterministic lowercase SHA-256 hexadecimal" do
    body = { "schema_version" => 1, "blocks" => [{ "type" => "paragraph" }] }

    digest = Cms::StructuredBody.digest_for(body)

    assert_match(/\A[0-9a-f]{64}\z/, digest)
    assert_equal digest, Cms::StructuredBody.digest_for(body.reverse_each.to_h)
  end

  test "validates schema and allowed block types without a database table" do
    record_class =
      Class.new do
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveModel::Validations
        include ActiveModel::Validations::Callbacks
        include Cms::StructuredBody::Validation

        attribute :body
        attribute :schema_version
        attribute :content_digest
      end
    record = record_class.new(body: { "schema_version" => 1, "blocks" => [{ "type" => "heading" }] }, schema_version: 1)

    assert record.valid?(:create)
    assert_match(/\A[0-9a-f]{64}\z/, record.content_digest)

    record.body = { "schema_version" => 2, "blocks" => [{ "type" => "video" }] }

    assert_not record.valid?
    assert_includes record.errors[:body], "schema_version must match schema_version"
    assert_includes record.errors[:body], "contains an unsupported block type"
  end
end
