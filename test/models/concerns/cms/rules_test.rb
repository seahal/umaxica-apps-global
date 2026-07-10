# typed: false
# frozen_string_literal: true

require "test_helper"

class CmsRulesTest < ActiveSupport::TestCase
  test "slug format accepts one lowercase ASCII character and rejects unsafe shapes" do
    assert Cms::SlugRules.valid_format?("a")
    assert Cms::SlugRules.valid_format?("a-1")
    assert_not Cms::SlugRules.valid_format?("A")
    assert_not Cms::SlugRules.valid_format?("-a")
    assert_not Cms::SlugRules.valid_format?("a--")
  end

  test "slug state timestamps are consistent" do
    now = Time.utc(2026, 7, 10)

    assert Cms::SlugRules.timestamps_valid?(state: "reserved", canonicalized_at: nil, redirected_at: nil)
    assert Cms::SlugRules.timestamps_valid?(state: "canonical", canonicalized_at: now, redirected_at: nil)
    assert Cms::SlugRules.timestamps_valid?(state: "redirect", canonicalized_at: now, redirected_at: now + 1)
    assert_not Cms::SlugRules.timestamps_valid?(state: "redirect", canonicalized_at: now, redirected_at: now - 1)
  end

  test "publication predicates use a half-open window" do
    publication = Struct.new(:effective_from, :effective_until, :cancelled_at, :terminated_at) do
      include Cms::PublicationPredicates
    end.new(Time.utc(2026, 7, 10, 10), Time.utc(2026, 7, 10, 11), nil, nil)

    assert publication.scheduled_at?(Time.utc(2026, 7, 10, 9))
    assert publication.effective_at?(Time.utc(2026, 7, 10, 10))
    assert_not publication.effective_at?(Time.utc(2026, 7, 10, 11))
    assert publication.ended_at?(Time.utc(2026, 7, 10, 11))
    assert publication.naturally_expired_at?(Time.utc(2026, 7, 10, 11))
  end

  test "taxonomy normalization applies NFKC case folding and whitespace collapse" do
    assert_equal "hello world", Cms::TaxonomyNormalization.normalize("  ＨＥＬＬＯ\tWorld  ")
  end

  test "owner and restoration cardinalities are explicit" do
    assert Cms::OwnershipRules.at_most_one?(Object.new, nil)
    assert_not Cms::OwnershipRules.at_most_one?(Object.new, Object.new)
    assert Cms::OwnershipRules.exactly_one?(Object.new, nil)
    assert_not Cms::OwnershipRules.exactly_one?(nil, nil)
  end

  test "immutable records become readonly only after persistence" do
    transient = Struct.new(:persisted?).new(false)
    persisted = Struct.new(:persisted?).new(true)

    assert_not Cms::ImmutableRecord.readonly_record?(transient)
    assert Cms::ImmutableRecord.readonly_record?(persisted)
  end
end
