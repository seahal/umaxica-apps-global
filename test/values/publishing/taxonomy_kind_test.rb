# frozen_string_literal: true

require "test_helper"

module Publishing
  class TaxonomyKindTest < ActiveSupport::TestCase
    # One contract, exercised against both providers.
    test "every registered kind answers the whole protocol" do
      TaxonomyKind::KEYS.each do |key|
        provider = TaxonomyKind.fetch(key)

        assert_equal key, provider.key
        assert_includes [true, false], provider.hierarchical?
        assert_includes [true, false], provider.ordered?
        assert_respond_to provider, :serialize
      end
    end

    test "the registry is closed and explicit" do
      assert_equal TaxonomyKind::KEYS.sort, TaxonomyKind.keys.sort
      assert_raises(TaxonomyKind::UnknownKindError) { TaxonomyKind.fetch("invented_kind") }
    end

    test "a single hierarchical kind supports hierarchy and not ordering" do
      provider = TaxonomyKind.fetch(TaxonomyKind::SINGLE_HIERARCHICAL)

      assert_predicate provider, :hierarchical?
      assert_not_predicate provider, :ordered?
      assert_nil provider.serialize([])
    end

    test "a multiple ordered flat kind supports ordering and not hierarchy" do
      provider = TaxonomyKind.fetch(TaxonomyKind::MULTIPLE_ORDERED_FLAT)

      assert_not_predicate provider, :hierarchical?
      assert_predicate provider, :ordered?
      assert_empty provider.serialize([])
    end

    test "a vocabulary resolves its own structural kind" do
      category = publishing_category_vocabulary(audience: "app", surface: "docs")
      tag = publishing_tag_vocabulary(audience: "app", surface: "docs")

      assert_predicate category.structural_kind, :hierarchical?
      assert_predicate tag.structural_kind, :ordered?
    end
  end
end
