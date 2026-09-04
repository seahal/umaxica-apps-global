# frozen_string_literal: true

require "test_helper"

class PublishingRevisionContentDigestTest < ActiveSupport::TestCase
  test "is a 64-character lowercase hex digest" do
    digest = PublishingRevisionContentDigest.call(
      schema_version: 1,
      locale: "ja",
      title: "Guide",
      summary: "Summary",
      body: { "text" => "Hello" },
    )

    assert_match(/\A[0-9a-f]{64}\z/, digest)
  end

  test "changes when title changes" do
    original = PublishingRevisionContentDigest.call(
      schema_version: 1, locale: "ja", title: "A", summary: nil, body: {},
    )
    changed = PublishingRevisionContentDigest.call(
      schema_version: 1, locale: "ja", title: "B", summary: nil, body: {},
    )

    assert_not_equal original, changed
  end

  test "is stable under object key order" do
    left = PublishingRevisionContentDigest.call(
      schema_version: 1, locale: "ja", title: "T", summary: nil, body: { "b" => 1, "a" => 2 },
    )
    right = PublishingRevisionContentDigest.call(
      schema_version: 1, locale: "ja", title: "T", summary: nil, body: { "a" => 2, "b" => 1 },
    )

    assert_equal left, right
  end
end
