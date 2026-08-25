# frozen_string_literal: true

require "test_helper"

module Publishing
  class MoveTaxonomySubtreeTest < ActiveSupport::TestCase
    setup do
      @category = publishing_category_vocabulary(audience: "app", surface: "docs")
      @guide = publishing_term(vocabulary: @category, locale: "ja", slug: "guide")
      @setup = publishing_term(vocabulary: @category, locale: "ja", slug: "setup", parent: @guide)
      @install = publishing_term(vocabulary: @category, locale: "ja", slug: "install", parent: @setup)
      @reference = publishing_term(vocabulary: @category, locale: "ja", slug: "reference")
    end

    test "moves a root under another root and recalculates descendant depth" do
      MoveTaxonomySubtree.call(term: @guide, new_parent: @reference)

      assert_equal 1, @guide.reload.depth
      assert_equal 2, @setup.reload.depth
      assert_equal 3, @install.reload.depth
      assert_equal @reference, @guide.parent
    end

    test "moves a subtree to the root" do
      MoveTaxonomySubtree.call(term: @setup, new_parent: nil)

      assert_predicate @setup.reload, :root?
      assert_equal 0, @setup.depth
      assert_equal 1, @install.reload.depth
    end

    test "lists ancestors and descendants in order and builds a breadcrumb" do
      assert_equal [@guide, @setup], @install.ancestors
      assert_equal [@setup, @install], @guide.descendants.order(:depth).to_a
      assert_equal %w(guide setup install), @install.breadcrumb.map { |step| step.fetch("slug") }
    end

    test "rejects a self-referential move" do
      assert_raises(MoveTaxonomySubtree::CycleError) { MoveTaxonomySubtree.call(term: @guide, new_parent: @guide) }
    end

    test "rejects moving a term under its own descendant" do
      assert_raises(MoveTaxonomySubtree::CycleError) { MoveTaxonomySubtree.call(term: @guide, new_parent: @install) }
    end

    test "rejects a cross-vocabulary or cross-locale move" do
      other_vocabulary = publishing_category_vocabulary(audience: "com", surface: "docs")
      foreign = publishing_term(vocabulary: other_vocabulary, locale: "ja", slug: "foreign")
      english = publishing_term(vocabulary: @category, locale: "en", slug: "english")

      assert_raises(MoveTaxonomySubtree::ScopeMismatchError) { MoveTaxonomySubtree.call(term: @guide, new_parent: foreign) }
      assert_raises(MoveTaxonomySubtree::ScopeMismatchError) { MoveTaxonomySubtree.call(term: @guide, new_parent: english) }
    end

    test "rejects a move that would push a descendant past the depth limit and leaves the tree unchanged" do
      deepest = @reference
      (TaxonomyTerm::MAX_DEPTH - 1).times do |level|
        deepest = publishing_term(vocabulary: @category, locale: "ja", slug: "chain-#{level}", parent: deepest)
      end

      assert_equal TaxonomyTerm::MAX_DEPTH - 1, deepest.depth
      assert_raises(MoveTaxonomySubtree::DepthLimitError) { MoveTaxonomySubtree.call(term: @guide, new_parent: deepest) }

      assert_predicate @guide.reload, :root?
      assert_equal 1, @setup.reload.depth
      assert_equal 2, @install.reload.depth
    end

    test "a failed move rolls back every row it had already touched" do
      original_parent = @setup.parent_id

      assert_raises(ActiveRecord::StatementInvalid) do
        MoveTaxonomySubtree.new(term: @setup, new_parent: @setup).send(:apply_move)
      end

      assert_equal original_parent, @setup.reload.parent_id
      assert_equal 1, @setup.depth
    end
  end
end
