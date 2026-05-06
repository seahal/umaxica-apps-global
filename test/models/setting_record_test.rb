# typed: false
# frozen_string_literal: true

require "test_helper"

class SettingRecordTest < ActiveSupport::TestCase
  class SettingRecordTestModel < SettingRecord
    self.table_name = "setting_record_test_models"
  end

  setup do
    @connection = SettingRecord.connection
    @connection.create_table(:setting_record_test_models, force: true) do |t|
      t.integer(:position)
      t.timestamps
    end
    SettingRecordTestModel.reset_column_information
  end

  teardown do
    @connection.drop_table(:setting_record_test_models, if_exists: true)
  end

  test "assigns the next position before validation" do
    SettingRecordTestModel.create!

    record = SettingRecordTestModel.create!

    assert_equal 2, record.position
  end
end
