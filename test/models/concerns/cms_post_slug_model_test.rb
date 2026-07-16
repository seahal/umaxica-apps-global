# typed: false
# frozen_string_literal: true

require "test_helper"

class CmsPostSlugModelTest < ActiveSupport::TestCase
  test "post slugs validate state, format, and timestamp combinations" do
    post = AppNewsPost.new
    reserved = AppNewsPostSlug.new(locale: "ja", slug: "news", state: "reserved", post:)

    assert_predicate reserved, :valid?

    canonical_without_timestamp = AppNewsPostSlug.new(locale: "ja", slug: "news", state: "canonical", post:)

    assert_not canonical_without_timestamp.valid?
    assert_includes canonical_without_timestamp.errors.attribute_names, :state

    redirect_without_timestamps = AppNewsPostSlug.new(locale: "ja", slug: "news", state: "redirect", post:)

    assert_not redirect_without_timestamps.valid?
    assert_includes redirect_without_timestamps.errors.attribute_names, :state

    valid_redirect = AppNewsPostSlug.new(
      locale: "ja",
      slug: "news-redirect",
      state: "redirect",
      post:,
      canonicalized_at: 2.hours.ago,
      redirected_at: 1.hour.ago,
    )

    assert_predicate valid_redirect, :valid?

    invalid_format = AppNewsPostSlug.new(locale: "ja", slug: "Unsafe Slug", state: "reserved", post:)

    assert_not invalid_format.valid?
    assert_includes invalid_format.errors.attribute_names, :slug

    invalid_state = AppNewsPostSlug.new(locale: "ja", slug: "news", state: "unknown", post:)

    assert_not invalid_state.valid?
    assert_includes invalid_state.errors.attribute_names, :state

    immutable = AppNewsPostSlug.new(locale: "ja", slug: "immutable", state: "reserved", post:)

    assert_not immutable.valid?(:update)
    assert_includes immutable.errors.attribute_names, :locale
  end
end
