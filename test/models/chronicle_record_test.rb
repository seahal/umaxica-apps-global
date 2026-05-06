# typed: false
# frozen_string_literal: true

require "test_helper"

class ChronicleRecordTest < ActiveSupport::TestCase
  test "connects to chronicle database" do
    config = ChronicleRecord.connection_db_config

    assert_equal "chronicle", config.name
    assert_match(/^test_chronicle_db(_\d+)?$/, config.database)
    assert_match(/^test_chronicle_db(_\d+)?$/, ChronicleRecord.connection.select_value("SELECT current_database()"))
  end

  test "can perform basic write and read via chronicle model" do
    temp_id = 99_991
    UserChronicleLevel.where(id: temp_id).delete_all

    record = UserChronicleLevel.create!(id: temp_id)

    assert_equal temp_id, record.id
    assert_equal record, UserChronicleLevel.find(temp_id)
  ensure
    UserChronicleLevel.where(id: temp_id).delete_all
  end
end
