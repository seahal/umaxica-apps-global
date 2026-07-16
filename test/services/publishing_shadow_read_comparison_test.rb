# frozen_string_literal: true

require "test_helper"

class PublishingShadowReadComparisonTest < ActiveSupport::TestCase
  test "reports parity once the legacy row has been imported into publishing" do
    DocsAppContentEntry.create!(
      slug: "shadow-read-parity", locale: "ja", title: "T", summary: "S", body: "hello",
      status: "published", published_at: 1.hour.ago,
    )
    PublishingMigrationImportLeanEntries.call(apply: true)

    result = PublishingShadowReadComparison.call(audience: "app", surface: "docs", locale: "ja")

    assert result.summary[:parity]
    assert result.summary[:counts_match]
    assert_empty result.details[:field_diffs]
  end

  test "reports a mismatch when publishing has not been imported yet" do
    DocsAppContentEntry.create!(
      slug: "shadow-read-missing", locale: "ja", title: "T", summary: "S", body: "hello",
      status: "published", published_at: 1.hour.ago,
    )

    result = PublishingShadowReadComparison.call(audience: "app", surface: "docs", locale: "ja")

    assert_not result.summary[:parity]
  end
end
