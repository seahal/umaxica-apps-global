# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class MigrationHelpersSafeTableRenameCoverageTest < ActiveSupport::TestCase
  class Harness
    include MigrationHelpersSafeTableRename

    attr_reader :renamed, :said

    def initialize(existing_tables)
      @existing_tables = existing_tables
      @renamed = nil
      @said = nil
    end

    def table_exists?(name)
      @existing_tables.include?(name.to_s)
    end

    def rename_table(old_table, new_table)
      @renamed = [old_table, new_table]
    end

    def say(message, _subitem = false)
      @said = message
    end

    def safety_assured
      yield
    end
  end

  test "renames when only the old table exists" do
    harness = Harness.new(%w(old_table))

    harness.rename_table_strict(:old_table, :new_table)

    assert_equal [:old_table, :new_table], harness.renamed
    assert_nil harness.said
  end

  test "skips when the new table already exists" do
    harness = Harness.new(%w(new_table))

    harness.rename_table_strict(:old_table, :new_table)

    assert_nil harness.renamed
    assert_equal "  skipped: old_table -> new_table (already renamed)", harness.said
  end

  test "raises on inconsistent table state" do
    both = Harness.new(%w(old_table new_table))
    missing = Harness.new([])

    assert_raises(MigrationHelpersSafeTableRename::InconsistentState) do
      both.rename_table_strict(:old_table, :new_table)
    end

    assert_raises(MigrationHelpersSafeTableRename::InconsistentState) do
      missing.rename_table_strict(:old_table, :new_table)
    end
  end
end
