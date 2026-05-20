# typed: false
# frozen_string_literal: true

require "test_helper"

class ComPrincipalRecordTest < ActiveSupport::TestCase
  test "is abstract" do
    assert_predicate ComPrincipalRecord, :abstract_class?
  end

  test "connects to com_principal db" do
    assert_equal :com_principal, ComPrincipalRecord.connection_db_config.name.to_sym
  end
end
