# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  class ApplicationRecordTestModel < OrgPrincipalRecord
    # This model inherits from OrgPrincipalRecord, which inherits from ApplicationRecord
  end

  def setup
    super
    @connection = OrgPrincipalRecord.connection
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

  test "insert_missing_fixed_ids! skips blank ids and de-duplicates rows" do
    calls = []

    ApplicationRecordTestModel.stub(:insert_all, ->(rows, **options) { calls << [rows, options] }) do
      assert_nil ApplicationRecordTestModel.insert_missing_fixed_ids!(nil)
      assert_nil ApplicationRecordTestModel.insert_missing_fixed_ids!([])

      ApplicationRecordTestModel.insert_missing_fixed_ids!([501, 501])
    end

    assert_equal 1, calls.size
    assert_equal 501, calls.first.first.first["id"]
  end

  test "insert_missing_fixed_ids! uses cache when fixed rows are still present" do
    ApplicationRecordTestModel.insert_missing_fixed_ids!([551])

    ApplicationRecordTestModel.stub(:insert_all, ->(*) { flunk("insert_all should not run for cached present ids") }) do
      assert_no_difference "ApplicationRecordTestModel.count" do
        ApplicationRecordTestModel.insert_missing_fixed_ids!([551])
      end
    end
  end

  test "insert_missing_fixed_ids! checks cached fixed rows with one id lookup" do
    ids = [561, 562, 563]
    ApplicationRecordTestModel.insert_missing_fixed_ids!(ids)

    queries =
      capture_test_model_sql do
        ApplicationRecordTestModel.insert_missing_fixed_ids!(ids)
      end

    table_selects = queries.grep(/FROM "application_record_test_models"/)

    assert_equal 1, table_selects.size
    assert_match(/SELECT "application_record_test_models"."id"/, table_selects.first)
  end

  test "insert_missing_fixed_ids! repairs stale cache when a fixed row is missing" do
    ApplicationRecordTestModel.insert_missing_fixed_ids!([601])
    ApplicationRecordTestModel.where(id: 601).delete_all

    assert_difference "ApplicationRecordTestModel.count", 1 do
      ApplicationRecordTestModel.insert_missing_fixed_ids!([601])
    end

    assert ApplicationRecordTestModel.exists?(id: 601)
  end

  private

  def capture_test_model_sql
    queries = []
    subscription =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
        next if payload[:name] == "SCHEMA"
        next if payload[:cached]

        queries << payload[:sql].to_s
      end

    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end
end
