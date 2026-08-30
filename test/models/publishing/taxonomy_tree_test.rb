# frozen_string_literal: true

require "test_helper"

module Publishing
  # parent_id/depth are structural columns, so the tree readers a caller relies
  # on are exercised against real rows rather than an in-memory graph.
  class TaxonomyTreeTest < ActiveSupport::TestCase
    setup do
      @category = publishing_category_vocabulary(audience: "app", surface: "news")
      @root = publishing_term(vocabulary: @category, locale: "ja", slug: "root", name: "Root")
      @child = publishing_term(vocabulary: @category, locale: "ja", slug: "child", name: "Child", parent: @root)
      @grandchild = publishing_term(vocabulary: @category, locale: "ja", slug: "grandchild", name: "Grandchild", parent: @child)
      @sibling = publishing_term(vocabulary: @category, locale: "ja", slug: "sibling", name: "Sibling")
    end

    test "root_terms returns the vocabulary's parentless terms only" do
      root_terms = @category.root_terms

      assert_equal [@root, @sibling].map(&:id).sort, root_terms.map(&:id).sort
    end

    test "root_terms is scoped to its own vocabulary" do
      other = publishing_tag_vocabulary(audience: "app", surface: "news")
      publishing_term(vocabulary: other, locale: "ja", slug: "ruby", name: "Ruby")

      assert_not_includes @category.root_terms.map(&:vocabulary_id), other.id
    end

    test "descendants walks the whole subtree and excludes the term itself and its siblings" do
      descendants = @root.descendants

      assert_equal [@child, @grandchild].map(&:id).sort, descendants.map(&:id).sort
      assert_not_includes descendants.map(&:id), @root.id
      assert_not_includes descendants.map(&:id), @sibling.id
    end

    test "a leaf term has no descendants" do
      assert_empty @grandchild.descendants
      assert_empty @sibling.descendants
    end
  end
end
