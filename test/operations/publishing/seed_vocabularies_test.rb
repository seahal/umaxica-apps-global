# frozen_string_literal: true

require "test_helper"

module Publishing
  class SeedVocabulariesTest < ActiveSupport::TestCase
    test "creates category and tag for every audience and surface" do
      SeedVocabularies.call

      expected = Edition::AUDIENCES.size * Edition::SURFACES.size

      assert_equal expected, Vocabulary.where(key: "category").count
      assert_equal expected, Vocabulary.where(key: "tag").count
      assert_equal TaxonomyKind::SINGLE_HIERARCHICAL, Vocabulary.find_by(audience: "app", surface: "docs", key: "category").kind
      assert_equal TaxonomyKind::MULTIPLE_ORDERED_FLAT, Vocabulary.find_by(audience: "org", surface: "news", key: "tag").kind
    end

    test "is idempotent" do
      SeedVocabularies.call
      before = Vocabulary.order(:id).pluck(:id, :audience, :surface, :key, :kind)

      SeedVocabularies.call

      assert_equal before, Vocabulary.order(:id).pluck(:id, :audience, :surface, :key, :kind)
    end

    test "locale is a property of terms, so one vocabulary row serves every locale" do
      SeedVocabularies.call
      category = Vocabulary.find_by(audience: "app", surface: "docs", key: "category")

      publishing_term(vocabulary: category, locale: "ja", slug: "guide")
      publishing_term(vocabulary: category, locale: "en", slug: "guide")

      assert_equal 2, category.terms.count
      assert_not_includes Vocabulary.column_names, "locale"
    end

    test "a conflicting existing definition fails loudly instead of being rewritten" do
      Vocabulary.create!(
        audience: "app", surface: "docs", key: "category",
        kind: TaxonomyKind::MULTIPLE_ORDERED_FLAT, internal_name: "Wrong Kind",
      )

      error = assert_raises(SeedVocabularies::ConflictingVocabularyError) { SeedVocabularies.call }

      assert_match(/app\/docs\/category/, error.message)
      assert_equal TaxonomyKind::MULTIPLE_ORDERED_FLAT, Vocabulary.find_by(audience: "app", surface: "docs", key: "category").kind
    end
  end
end
