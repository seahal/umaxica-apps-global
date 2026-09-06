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

  # The digest sorts keys at every level, so a hash the caller built with symbols has to reach the
  # same bytes as the JSON-parsed hash the CMS produces. Otherwise the same content revised through
  # the form and through Ruby would look like two different revisions.
  test "a symbol-keyed body digests the same as its string-keyed equivalent" do
    symbols = PublishingRevisionContentDigest.call(
      schema_version: 1, locale: "ja", title: "T", summary: nil,
      body: { blocks: { kind: "p", text: "x" } },
    )
    strings = PublishingRevisionContentDigest.call(
      schema_version: 1, locale: "ja", title: "T", summary: nil,
      body: { "blocks" => { "text" => "x", "kind" => "p" } },
    )

    assert_equal strings, symbols
  end

  # Arrays are ordered content, not a set: reordering blocks is a different document.
  test "array order is part of the digest while the objects inside are still normalised" do
    forward = PublishingRevisionContentDigest.call(
      schema_version: 1, locale: "ja", title: "T", summary: nil,
      body: { "blocks" => [{ "a" => 1, "b" => 2 }, { "c" => 3 }] },
    )
    reordered_keys = PublishingRevisionContentDigest.call(
      schema_version: 1, locale: "ja", title: "T", summary: nil,
      body: { "blocks" => [{ "b" => 2, "a" => 1 }, { "c" => 3 }] },
    )
    reordered_items = PublishingRevisionContentDigest.call(
      schema_version: 1, locale: "ja", title: "T", summary: nil,
      body: { "blocks" => [{ "c" => 3 }, { "a" => 1, "b" => 2 }] },
    )

    assert_equal forward, reordered_keys
    assert_not_equal forward, reordered_items
  end
end
