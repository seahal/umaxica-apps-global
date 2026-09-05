# frozen_string_literal: true

require "test_helper"

module Publishing
  class TaxonomyRetirementTest < ActiveSupport::TestCase
    setup do
      @category = publishing_category_vocabulary(audience: "app", surface: "docs")
      @term = publishing_term(vocabulary: @category, locale: "ja", slug: "retire-me")
      @connection = PublishingRecord.lease_connection
      @vocab_table = @category.class.table_name
      @term_table = @term.class.table_name
    end

    test "a term cannot be physically deleted even when nothing references it" do
      assert_database_rejects { @connection.execute("DELETE FROM #{@term_table} WHERE id = #{@term.id}") }
      assert_database_rejects { @term.destroy! }
      assert_predicate @term.class.find_by(id: @term.id), :present?
    end

    test "a vocabulary cannot be physically deleted even when it has no terms" do
      empty = @category.class.create!(key: "empty", kind: TaxonomyKind::MULTIPLE_ORDERED_FLAT, internal_name: "Empty")

      assert_database_rejects { @connection.execute("DELETE FROM #{@vocab_table} WHERE id = #{empty.id}") }
      assert_predicate @category.class.find_by(id: empty.id), :present?
    end

    test "a vocabulary's structural identity is frozen" do
      %w(public_id key kind).each do |column|
        value = (column == "kind") ? TaxonomyKind::MULTIPLE_ORDERED_FLAT : "x" * 4
        assert_database_rejects do
          @connection.execute("UPDATE #{@vocab_table} SET #{column} = '#{value}' WHERE id = #{@category.id}")
        end
      end

      assert_equal TaxonomyKind::SINGLE_HIERARCHICAL, @category.reload.kind
    end

    test "an empty vocabulary may still be relabelled" do
      draft = @category.class.create!(
        key: "wrong_kind", kind: TaxonomyKind::SINGLE_HIERARCHICAL, internal_name: "Draft",
      )

      draft.update!(internal_name: "Corrected")

      assert_equal "Corrected", draft.reload.internal_name
    end

    test "archiving is reversible and does not release the slug for reuse" do
      @term.update!(archived_at: Time.current, archive_reason: "retired")

      assert_raises(ActiveRecord::RecordNotUnique) do
        publishing_term(vocabulary: @category, locale: "ja", slug: "retire-me")
      end

      @term.update!(archived_at: nil, archive_reason: nil)
      assert_not @term.reload.archived?
    end
  end
end
