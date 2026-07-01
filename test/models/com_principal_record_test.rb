# typed: false
# frozen_string_literal: true

require "test_helper"

class ComPrincipalRecordTest < ActiveSupport::TestCase
  test "is abstract" do
    assert_predicate ComPrincipalRecord, :abstract_class?
  end

  test "uses the consolidated com zenith database" do
    assert_equal "com_zenith", ComPrincipalRecord.connection_db_config.name
    assert_equal ComRpRecord.connection_db_config.name, ComPrincipalRecord.connection_db_config.name
  end
end
