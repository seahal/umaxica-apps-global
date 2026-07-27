# frozen_string_literal: true

require "test_helper"
require_relative "../../db/migration_support/publishing_legacy_table_drop"

class PublishingLegacyTableDropTest < ActiveSupport::TestCase
  FakeConnection =
    Struct.new(:existing_tables, :row_counts) do
      def table_exists?(table)
        existing_tables.include?(table.to_s)
      end

      def quote_table_name(table)
        %Q("#{table}")
      end

      def select_value(sql)
        table = sql.match(/FROM "([^"]+)"/)[1]
        row_counts.fetch(table, 0)
      end

      # None of the fake tables carry real foreign keys; the fixtures only
      # need to exercise the drop/empty-check paths above.
      def foreign_keys(_table)
        []
      end
    end

  class FakeMigration
    attr_reader :connection, :drops, :removed_foreign_keys

    def initialize(existing_tables:, row_counts: {})
      @connection = FakeConnection.new(existing_tables.map(&:to_s), row_counts.transform_keys(&:to_s))
      @drops = []
      @removed_foreign_keys = []
    end

    def safety_assured
      yield
    end

    def drop_table(table, **options)
      drops << [table.to_s, options]
    end

    def remove_foreign_key(table, **options)
      removed_foreign_keys << [table.to_s, options]
    end
  end

  test "production drop requires the exact approval value before inspecting or dropping tables" do
    migration = FakeMigration.new(existing_tables: PublishingLegacyTableDrop.tables_for(surface: :app))
    production = ActiveSupport::EnvironmentInquirer.new("production")

    Rails.stub(:env, production) do
      ENV.stub(:fetch, ->(name) { raise KeyError, "key not found: #{name}" }) do
        error =
          assert_raises(PublishingLegacyTableDrop::PreconditionError) do
            PublishingLegacyTableDrop.call(migration, surface: :app)
          end

        assert_match(/PUBLISHING_LEGACY_TABLE_DROP_APPROVAL/, error.message)
      end
    end

    assert_empty migration.drops
  end

  test "production drop rejects an incorrect approval value" do
    migration = FakeMigration.new(existing_tables: PublishingLegacyTableDrop.tables_for(surface: :com))
    production = ActiveSupport::EnvironmentInquirer.new("production")

    Rails.stub(:env, production) do
      ENV.stub(:fetch, "not-approved") do
        assert_raises(PublishingLegacyTableDrop::PreconditionError) do
          PublishingLegacyTableDrop.call(migration, surface: :com)
        end
      end
    end

    assert_empty migration.drops
  end

  test "drop refuses a missing expected table without dropping anything" do
    tables = PublishingLegacyTableDrop.tables_for(surface: :org)
    migration = FakeMigration.new(existing_tables: tables.drop(1))

    error =
      assert_raises(PublishingLegacyTableDrop::PreconditionError) do
        PublishingLegacyTableDrop.call(migration, surface: :org)
      end

    assert_match(/missing expected legacy publishing tables/, error.message)
    assert_empty migration.drops
  end

  test "drop refuses a nonempty expected table without dropping anything" do
    tables = PublishingLegacyTableDrop.tables_for(surface: :app)
    migration = FakeMigration.new(existing_tables: tables, row_counts: { "app_docs_posts" => 2 })

    error =
      assert_raises(PublishingLegacyTableDrop::PreconditionError) do
        PublishingLegacyTableDrop.call(migration, surface: :app)
      end

    assert_match(/app_docs_posts=2/, error.message)
    assert_empty migration.drops
  end

  test "empty app com and org legacy tables drop in dependency order without cascade or if_exists" do
    %i(app com org).each do |surface|
      expected_tables = PublishingLegacyTableDrop.tables_for(surface: surface)
      migration = FakeMigration.new(existing_tables: expected_tables)

      PublishingLegacyTableDrop.call(migration, surface: surface)

      assert_equal expected_tables, migration.drops.map(&:first), surface
      nonempty_options = migration.drops.filter_map { |table, options| table if options.present? }

      assert_empty nonempty_options, surface
    end
  end
end
