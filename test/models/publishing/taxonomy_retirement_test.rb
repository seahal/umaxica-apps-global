# frozen_string_literal: true

require "test_helper"

module Publishing
  # Taxonomy identity is retired by archiving, never by deletion, so that a
  # published snapshot naming a term can never be silently reinterpreted by a
  # different term reusing its identity.
  class TaxonomyRetirementTest < ActiveSupport::TestCase
    setup do
      @category = publishing_category_vocabulary(audience: "app", surface: "docs")
      @term = publishing_term(vocabulary: @category, locale: "ja", slug: "retire-me")
      @connection = PublishingRecord.lease_connection
    end

    test "a term cannot be physically deleted even when nothing references it" do
      assert_database_rejects { @connection.execute("DELETE FROM publishing_taxonomy_terms WHERE id = #{@term.id}") }
      assert_database_rejects { @term.destroy! }
      assert_predicate TaxonomyTerm.find_by(id: @term.id), :present?
    end

    test "a vocabulary cannot be physically deleted even when it has no terms" do
      empty = Vocabulary.create!(
        audience: "org", surface: "help", key: "empty", kind: TaxonomyKind::MULTIPLE_ORDERED_FLAT, internal_name: "Empty",
      )

      assert_database_rejects { @connection.execute("DELETE FROM publishing_vocabularies WHERE id = #{empty.id}") }
      assert_predicate Vocabulary.find_by(id: empty.id), :present?
    end

    test "a vocabulary's structural identity is frozen once it has terms" do
      %w(public_id audience surface key kind).each do |column|
        value = (column == "kind") ? TaxonomyKind::MULTIPLE_ORDERED_FLAT : "x" * 4
        assert_database_rejects do
          @connection.execute("UPDATE publishing_vocabularies SET #{column} = '#{value}' WHERE id = #{@category.id}")
        end
      end

      assert_equal TaxonomyKind::SINGLE_HIERARCHICAL, @category.reload.kind
    end

    test "an empty vocabulary may still be corrected" do
      draft = Vocabulary.create!(
        audience: "com", surface: "help", key: "wrong_kind", kind: TaxonomyKind::SINGLE_HIERARCHICAL, internal_name: "Draft",
      )

      draft.update!(kind: TaxonomyKind::MULTIPLE_ORDERED_FLAT)

      assert_equal TaxonomyKind::MULTIPLE_ORDERED_FLAT, draft.reload.kind
    end

    test "archiving is reversible and does not release the slug for reuse" do
      @term.update!(archived_at: Time.current, archive_reason: "retired")

      assert_raises(ActiveRecord::RecordNotUnique) { publishing_term(vocabulary: @category, locale: "ja", slug: "retire-me") }

      @term.update!(archived_at: nil, archive_reason: nil)

      assert_not_predicate @term.reload, :archived?
    end

    test "a term is unpublishable when any ancestor on its path is archived" do
      parent = publishing_term(vocabulary: @category, locale: "ja", slug: "ancestor")
      child = publishing_term(vocabulary: @category, locale: "ja", slug: "descendant", parent:)

      assert_empty child.archived_in_path

      parent.update!(archived_at: Time.current, archive_reason: "retired")

      assert_equal [parent.id], child.reload.archived_in_path.map(&:id)
      assert_not_predicate child, :archived?
    end

    test "archiving a parent leaves its children addressable but unpublishable" do
      parent = publishing_term(vocabulary: @category, locale: "ja", slug: "still-parent")
      child = publishing_term(vocabulary: @category, locale: "ja", slug: "still-child", parent:)
      parent.update!(archived_at: Time.current, archive_reason: "retired")

      assert_equal parent, child.reload.parent
      assert_any_archived(child)
    end

    private

    def assert_any_archived(term)
      assert_not_empty term.archived_in_path, "expected #{term.slug} to be blocked by an archived ancestor"
    end
  end
end
