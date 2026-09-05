# frozen_string_literal: true

require "test_helper"

module Publishing
  # These tests write invalid rows deliberately, bypassing Active Record
  # validations where necessary, to prove PostgreSQL is the enforcement layer.
  class TaxonomyConstraintsTest < ActiveSupport::TestCase
    setup do
      @category = publishing_category_vocabulary(audience: "app", surface: "docs")
      @tag = publishing_tag_vocabulary(audience: "app", surface: "docs")
    end

    test "vocabulary key is unique within a family and independent across families" do
      assert_raises(ActiveRecord::RecordNotUnique) do
        Publishing::Docs::App::Vocabulary.new(
          key: "category", kind: @category.kind, internal_name: "Dup",
        ).save!(validate: false)
      end

      Publishing::Docs::App::Vocabulary.create!(key: "topic", kind: @category.kind, internal_name: "Topic")
      other = Publishing::Docs::Com::Vocabulary.create!(
        key: "topic", kind: @category.kind, internal_name: "Topic",
      )

      assert_predicate other, :persisted?
    end

    test "vocabulary rejects an unknown kind or key format" do
      assert_raises(ActiveRecord::CheckViolation) do
        Publishing::News::App::Vocabulary.new(
          key: "k", kind: "sideways", internal_name: "N",
        ).save!(validate: false)
      end
      assert_raises(ActiveRecord::CheckViolation) do
        Publishing::News::App::Vocabulary.new(
          key: "Bad Key", kind: @category.kind, internal_name: "N",
        ).save!(validate: false)
      end
    end

    test "an archive timestamp and reason must be set together" do
      assert_raises(ActiveRecord::CheckViolation) { @category.update_column(:archived_at, Time.current) }
    end

    test "term slug is unique per vocabulary and locale" do
      publishing_term(vocabulary: @category, locale: "ja", slug: "guide")

      assert_raises(ActiveRecord::RecordNotUnique) { publishing_term(vocabulary: @category, locale: "ja", slug: "guide") }

      # The same slug in another locale is a different term, by design.
      assert_predicate publishing_term(vocabulary: @category, locale: "en", slug: "guide"), :persisted?
    end

    test "a term's parent must share its vocabulary and locale" do
      ja_root = publishing_term(vocabulary: @category, locale: "ja", slug: "root-ja")
      other_vocabulary = publishing_category_vocabulary(audience: "com", surface: "docs")
      other_root = publishing_term(vocabulary: other_vocabulary, locale: "ja", slug: "root-other")

      assert_raises(ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid) do
        Docs::App::TaxonomyTerm.new(
          vocabulary: @category, vocabulary_kind: @category.kind, locale: "ja", slug: "cross-vocabulary",
          name: "X", parent_id: other_root.id, depth: 1,
        ).save!(validate: false)
      end

      assert_raises(ActiveRecord::InvalidForeignKey) do
        Docs::App::TaxonomyTerm.new(
          vocabulary: @category, vocabulary_kind: @category.kind, locale: "en", slug: "cross-locale",
          name: "X", parent_id: ja_root.id, depth: 1,
        ).save!(validate: false)
      end
    end

    test "a flat vocabulary's term cannot have a parent" do
      root = publishing_term(vocabulary: @tag, locale: "ja", slug: "ruby")

      assert_raises(ActiveRecord::CheckViolation) do
        Docs::App::TaxonomyTerm.new(
          vocabulary: @tag, vocabulary_kind: @tag.kind, locale: "ja", slug: "rails", name: "Rails",
          parent_id: root.id, depth: 1,
        ).save!(validate: false)
      end
    end

    test "root and depth must agree" do
      assert_raises(ActiveRecord::CheckViolation) do
        Docs::App::TaxonomyTerm.new(
          vocabulary: @category, vocabulary_kind: @category.kind, locale: "ja", slug: "deep-root", name: "X", depth: 1,
        ).save!(validate: false)
      end

      root = publishing_term(vocabulary: @category, locale: "ja", slug: "depth-root")

      # The hierarchy trigger reaches this row before the CHECK does, so the
      # rejection surfaces as the more general StatementInvalid.
      assert_raises(ActiveRecord::StatementInvalid) do
        Docs::App::TaxonomyTerm.new(
          vocabulary: @category, vocabulary_kind: @category.kind, locale: "ja", slug: "zero-child", name: "X",
          parent_id: root.id, depth: 0,
        ).save!(validate: false)
      end
    end

    test "a term's depth must equal its parent's depth plus one" do
      root = publishing_term(vocabulary: @category, locale: "ja", slug: "trigger-root")

      assert_raises(ActiveRecord::StatementInvalid) do
        Docs::App::TaxonomyTerm.new(
          vocabulary: @category, vocabulary_kind: @category.kind, locale: "ja", slug: "skipped-depth", name: "X",
          parent_id: root.id, depth: 3,
        ).save!(validate: false)
      end
    end

    test "depth beyond the limit is rejected" do
      parent = publishing_term(vocabulary: @category, locale: "ja", slug: "level-0")
      Docs::App::TaxonomyTerm::MAX_DEPTH.times do |level|
        parent = publishing_term(vocabulary: @category, locale: "ja", slug: "level-#{level + 1}", parent:)
      end

      assert_equal Docs::App::TaxonomyTerm::MAX_DEPTH, parent.depth
      assert_raises(ActiveRecord::CheckViolation) do
        publishing_term(vocabulary: @category, locale: "ja", slug: "too-deep", parent:)
      end
    end

    test "postgresql rejects a cycle written behind the domain operation's back" do
      root = publishing_term(vocabulary: @category, locale: "ja", slug: "cycle-root")
      child = publishing_term(vocabulary: @category, locale: "ja", slug: "cycle-child", parent: root)

      # Both the descendant cycle and the self-parent case are caught by the
      # hierarchy trigger before the not-self CHECK is reached.
      assert_database_rejects { root.update_columns(parent_id: child.id, depth: 1) }
      assert_database_rejects { root.update_columns(parent_id: root.id, depth: 1) }
    end

    test "an assignment cannot use a vocabulary from another audience or surface" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "scope-entry", title: "Scope")
      foreign_vocabulary = publishing_category_vocabulary(audience: "org", surface: "news")
      foreign_term = publishing_term(vocabulary: foreign_vocabulary, locale: "ja", slug: "foreign")

      assert_raises(ActiveRecord::AssociationTypeMismatch, ActiveRecord::StatementInvalid, ActiveRecord::RecordInvalid) do
        create_single_assignment(
          entry_revision: entry.current_revision, vocabulary: foreign_vocabulary,
          vocabulary_kind: foreign_vocabulary.kind, taxonomy_term: foreign_term, locale: "ja",
        )
      end
    end

    test "an assignment cannot mix kinds or use a term from another vocabulary" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "kind-entry", title: "Kind")
      tag_term = publishing_term(vocabulary: @tag, locale: "ja", slug: "ruby")

      # A tag vocabulary in the single-valued table.
      assert_raises(ActiveRecord::CheckViolation) do
        entry.current_revision.single_taxonomy_assignments.new(
          entry_revision: entry.current_revision, vocabulary: @tag, vocabulary_kind: @tag.kind,
          taxonomy_term: tag_term, locale: "ja",
        ).save!(validate: false)
      end

      # A term that belongs to a different vocabulary than the one assigned.
      category_term = publishing_term(vocabulary: @category, locale: "ja", slug: "guide")

      assert_raises(ActiveRecord::InvalidForeignKey) do
        entry.current_revision.multiple_taxonomy_assignments.new(
          entry_revision: entry.current_revision, vocabulary: @tag, vocabulary_kind: @tag.kind,
          taxonomy_term: category_term, locale: "ja", position: 0,
        ).save!(validate: false)
      end
    end

    test "an assignment's locale must match its revision and its term" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "locale-entry", title: "Locale")
      english_term = publishing_term(vocabulary: @category, locale: "en", slug: "english-guide")

      assert_raises(ActiveRecord::InvalidForeignKey) do
        entry.current_revision.single_taxonomy_assignments.new(
          entry_revision: entry.current_revision, vocabulary: @category, vocabulary_kind: @category.kind,
          taxonomy_term: english_term, locale: "ja",
        ).save!(validate: false)
      end
    end

    test "single assignments are capped at one term per vocabulary" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "single-entry", title: "Single")
      first = publishing_term(vocabulary: @category, locale: "ja", slug: "first")
      second = publishing_term(vocabulary: @category, locale: "ja", slug: "second")

      create_single_assignment(
        entry_revision: entry.current_revision, vocabulary: @category, vocabulary_kind: @category.kind,
        taxonomy_term: first, locale: "ja",
      )

      assert_raises(ActiveRecord::RecordNotUnique) do
        create_single_assignment(
          entry_revision: entry.current_revision, vocabulary: @category, vocabulary_kind: @category.kind,
          taxonomy_term: second, locale: "ja",
        )
      end
    end

    test "multiple assignments reject duplicate terms and duplicate positions" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "multi-entry", title: "Multi")
      ruby = publishing_term(vocabulary: @tag, locale: "ja", slug: "ruby")
      rails = publishing_term(vocabulary: @tag, locale: "ja", slug: "rails")
      assign =
        lambda do |term, position|
          create_multiple_assignment(
            entry_revision: entry.current_revision, vocabulary: @tag, vocabulary_kind: @tag.kind,
            taxonomy_term: term, locale: "ja", position:,
          )
        end

      assign.call(ruby, 0)

      assert_raises(ActiveRecord::RecordNotUnique) { assign.call(ruby, 1) }
      assert_raises(ActiveRecord::RecordNotUnique) { assign.call(rails, 0) }
      assert_predicate assign.call(rails, 1), :persisted?
    end

    test "a negative position is rejected" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "position-entry", title: "Position")
      ruby = publishing_term(vocabulary: @tag, locale: "ja", slug: "ruby")

      assert_raises(ActiveRecord::CheckViolation) do
        entry.current_revision.multiple_taxonomy_assignments.new(
          entry_revision: entry.current_revision, vocabulary: @tag, vocabulary_kind: @tag.kind,
          taxonomy_term: ruby, locale: "ja", position: -1,
        ).save!(validate: false)
      end
    end
  end
end
