# typed: false
# frozen_string_literal: true

require "test_helper"

class ComSettingRecordTest < ActiveSupport::TestCase
  class ComSettingRecordTestModel < ComSettingRecord
    self.table_name = "com_setting_record_test_models"
  end

  setup do
    @connection = ComSettingRecord.connection
    @connection.create_table(:com_setting_record_test_models, force: true) do |t|
      t.integer(:position)
      t.timestamps
    end
    ComSettingRecordTestModel.reset_column_information
  end

  teardown do
    @connection.drop_table(:com_setting_record_test_models, if_exists: true)
  end

  test "assigns the next position before validation" do
    ComSettingRecordTestModel.create!

    record = ComSettingRecordTestModel.create!

    assert_equal 2, record.position
  end
end
