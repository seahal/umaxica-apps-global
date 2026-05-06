# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  class ApplicationRecordTestModel < OperatorRecord
    # This model inherits from OperatorRecord, which inherits from ApplicationRecord
  end

  def setup
    super
    @connection = OperatorRecord.connection
    @connection.create_table(:application_record_test_models, force: true) do |t|
      t.timestamps
    end
    ApplicationRecordTestModel.reset_column_information
  end

  def teardown
    @connection.drop_table(:application_record_test_models, if_exists: true)
    super
  end

  test "insert_missing_fixed_ids! inserts records" do
    ids = [101, 102, 103]
    ApplicationRecordTestModel.insert_missing_fixed_ids!(ids)

    assert_equal 3, ApplicationRecordTestModel.count
    assert_includes ApplicationRecordTestModel.pluck(:id), 101
    assert_includes ApplicationRecordTestModel.pluck(:id), 102
    assert_includes ApplicationRecordTestModel.pluck(:id), 103
  end

  test "insert_missing_fixed_ids! handles duplicates and ignores existing" do
    ApplicationRecordTestModel.create!(id: 101)

    ids = [101, 101, 102]
    ApplicationRecordTestModel.insert_missing_fixed_ids!(ids)

    assert_equal 2, ApplicationRecordTestModel.count
    assert_includes ApplicationRecordTestModel.pluck(:id), 101
    assert_includes ApplicationRecordTestModel.pluck(:id), 102
  end

  test "insert_missing_fixed_ids! does nothing when all ids exist" do
    ApplicationRecordTestModel.create!(id: 201)
    ApplicationRecordTestModel.create!(id: 202)

    assert_no_difference "ApplicationRecordTestModel.count" do
      ApplicationRecordTestModel.insert_missing_fixed_ids!([201, 202])
    end
  end

  test "insert_missing_fixed_ids! inserts only missing ids" do
    ApplicationRecordTestModel.create!(id: 301)

    ApplicationRecordTestModel.insert_missing_fixed_ids!([301, 302, 303])

    assert_equal 3, ApplicationRecordTestModel.count
    assert_includes ApplicationRecordTestModel.pluck(:id), 301
    assert_includes ApplicationRecordTestModel.pluck(:id), 302
    assert_includes ApplicationRecordTestModel.pluck(:id), 303
  end

  test "insert_missing_fixed_ids! handles empty array" do
    assert_no_difference "ApplicationRecordTestModel.count" do
      ApplicationRecordTestModel.insert_missing_fixed_ids!([])
    end
  end

  test "insert_missing_fixed_ids! sets timestamps" do
    ApplicationRecordTestModel.insert_missing_fixed_ids!([401])

    record = ApplicationRecordTestModel.find(401)

    assert_not_nil record.created_at
    assert_not_nil record.updated_at
  end
end
