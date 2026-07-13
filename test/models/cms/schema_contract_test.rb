# frozen_string_literal: true

require "test_helper"

class CmsSchemaContractTest < ActiveSupport::TestCase
  SURFACES = { "App" => AppPrincipalRecord, "Com" => ComPrincipalRecord, "Org" => OrgPrincipalRecord }.freeze
  FAMILIES = %w(Docs News Info Help).freeze
  SUFFIXES = %w(Post PostSlug PostRevision PostVersion PostPublication MediaFile MediaUsage Category Tag
                PostRevisionCategory PostRevisionTag PostVersionCategory PostVersionTag).freeze

  test "all 156 CMS model tables exist only on the owning surface database" do
    SURFACES.each do |surface, base|
      expected = FAMILIES.product(SUFFIXES).map { |family, suffix| "#{surface}#{family}#{suffix}".constantize.table_name }
      base.connection_pool.with_connection do |connection|
        expected.each { |table| assert connection.data_source_exists?(table), "missing #{table}" }
      end

      SURFACES.except(surface).each_value do |foreign_base|
        foreign_base.connection_pool.with_connection do |connection|
          expected.each { |table| assert_not connection.data_source_exists?(table), "#{table} is in the wrong database" }
        end
      end
    end
  end

  test "every model can load its column contract" do
    SURFACES.each_key do |surface|
      FAMILIES.each do |family|
        SUFFIXES.each do |suffix|
          model = "#{surface}#{family}#{suffix}".constantize

          assert_includes model.column_names, "public_id"
          assert_includes model.column_names, "created_at"
        end
      end
    end
  end

  test "all families receive shared indexes checks foreign keys and publication exclusion" do
    SURFACES.each do |surface, base|
      base.connection_pool.with_connection do |connection|
        FAMILIES.each do |family|
          prefix = "#{surface.downcase}_#{family.downcase}"

          assert_unique_index(connection, "#{prefix}_posts", %w(public_id))
          assert_unique_index(connection, "#{prefix}_post_slugs", %w(locale slug))
          assert_unique_index(connection, "#{prefix}_post_revisions", %w(post_id sequence))
          assert_unique_index(connection, "#{prefix}_post_versions", %w(post_revision_id))
          assert_operator connection.foreign_keys("#{prefix}_post_publications").size, :>=, 2
          assert_operator connection.check_constraints("#{prefix}_post_versions").size, :>=, 4
          constraint = connection.select_value(<<~SQL.squish)
            SELECT conname FROM pg_constraint WHERE conname = 'excl_#{prefix}_publication_windows'
          SQL
          assert_equal "excl_#{prefix}_publication_windows", constraint
        end
      end
    end
  end

  private

  def assert_unique_index(connection, table, columns)
    assert connection.indexes(table).any? { |index| index.unique && index.columns == columns },
           "missing unique index on #{table}(#{columns.join(",")})"
  end
end
