# typed: false
# frozen_string_literal: true

require "test_helper"

class ModelTableFixtureConsistencyTest < ActiveSupport::TestCase
  fixtures_none!

  PUBLISHER_POST_MODELS = [
    AppPost,
    AppPostCategory,
    AppPostCategoryMaster,
    AppPostReview,
    AppPostReviewStatus,
    AppPostRevision,
    AppPostStatus,
    AppPostTag,
    AppPostTagMaster,
    AppPostVersion,
    ComPost,
    ComPostCategory,
    ComPostCategoryMaster,
    ComPostReview,
    ComPostReviewStatus,
    ComPostRevision,
    ComPostStatus,
    ComPostTag,
    ComPostTagMaster,
    ComPostVersion,
    OrgPost,
    OrgPostCategory,
    OrgPostCategoryMaster,
    OrgPostReview,
    OrgPostReviewStatus,
    OrgPostRevision,
    OrgPostStatus,
    OrgPostTag,
    OrgPostTagMaster,
    OrgPostVersion,
  ].freeze

  test "application record table names follow model tableize convention" do
    Rails.application.eager_load!

    mismatches =
      application_record_models.filter_map do |model|
        expected = model.name.tableize
        actual = model.table_name
        "#{model.name}: expected #{expected}, got #{actual}" unless expected == actual
      end

    assert_empty mismatches.sort, "Model/table naming mismatches remain:\n#{mismatches.sort.join("\n")}"
  end

  test "fixture file names map to active record table names" do
    Rails.application.eager_load!

    table_names = application_record_models.map(&:table_name).to_set
    fixture_names = Rails.root.glob("test/fixtures/*.yml").map { |path| path.basename(".yml").to_s }
    missing_tables = fixture_names.reject { |fixture_name| table_names.include?(fixture_name) }

    assert_empty missing_tables.sort,
                 "Fixture files without matching model tables remain:\n#{missing_tables.sort.join("\n")}"
  end

  test "legacy unprefixed post compatibility constants are absent" do
    legacy_constants = %w(
      Post
      PostCategory
      PostCategoryMaster
      PostReview
      PostReviewStatus
      PostRevision
      PostStatus
      PostTag
      PostTagMaster
      PostVersion
    )

    remaining = legacy_constants.select { |constant_name| Object.const_defined?(constant_name) }

    assert_empty remaining, "Legacy unprefixed post constants remain: #{remaining.join(", ")}"
  end

  test "publisher post associations use surface-prefixed names and foreign keys" do
    PUBLISHER_POST_MODELS.each do |model|
      surface_prefix = model.name.match(/\A(App|Com|Org)/)[1].underscore
      model.reflect_on_all_associations.each do |association|
        next if association.options[:polymorphic]
        next unless association.klass.name.start_with?(surface_prefix.camelize)
        next if association.name.in?(%i(parent children latest_version_record latest_revision_record latest_post))

        assert_match(/\A#{Regexp.escape(surface_prefix)}_post/, association.name.to_s)
        assert_match(/\A(?:latest_)?#{Regexp.escape(surface_prefix)}_post/, association.foreign_key.to_s) if
          association.macro == :belongs_to
      end
    end
  end

  private
  def application_record_models
    ApplicationRecord.descendants.reject do |model|
      model.abstract_class? || model.name.include?("::")
    end
  end
end
