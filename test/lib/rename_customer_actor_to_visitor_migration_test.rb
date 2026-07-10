# typed: false
# frozen_string_literal: true

require "test_helper"

class RenameCustomerActorToVisitorMigrationTest < ActiveSupport::TestCase
  test "uses strict table renames" do
    source = Rails.root.join(
      "db/com_principals_migrate/20260513130000_rename_customer_actor_to_visitor.rb",
    ).read

    assert_includes source, "rename_table_strict old_name, new_name"
    assert_not_includes source, "rename_table(old_name, new_name) if"
  end
end
