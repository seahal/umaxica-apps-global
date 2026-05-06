# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: scavenger_regional_chronicles
# Database name: chronicle
#
#  id              :bigint           not null, primary key
#  error_message   :text
#  finished_at     :datetime
#  idempotency_key :string(128)      not null
#  job_type        :string(64)       not null
#  occurred_at     :datetime
#  payload         :jsonb
#  retry_count     :integer
#  started_at      :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_id        :bigint           default(0), not null
#  region_id       :bigint           not null
#  status_id       :bigint           default(0), not null
#
# Indexes
#
#  idx_on_region_id_idempotency_key_2dd0f63eee                    (region_id,idempotency_key) UNIQUE
#  index_scavenger_regional_chronicles_on_event_id                (event_id)
#  index_scavenger_regional_chronicles_on_occurred_at             (occurred_at)
#  index_scavenger_regional_chronicles_on_region_id_and_job_type  (region_id,job_type)
#  index_scavenger_regional_chronicles_on_status_id               (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => scavenger_regional_chronicle_events.id)
#  fk_rails_...  (status_id => scavenger_regional_chronicle_statuses.id)
#
require "test_helper"

class ScavengerRegionalChronicleTest < ActiveSupport::TestCase
  fixtures :scavenger_regional_chronicle_statuses, :scavenger_regional_chronicle_events, :scavenger_regional_chronicles

  test "loads NOTHING fixture with id 0" do
    assert_equal 0, scavenger_regional_chronicle_statuses(:nothing).id
    assert_equal 0, scavenger_regional_chronicle_events(:nothing).id
  end

  test "persists with default lookup ids when omitted" do
    record = ScavengerRegionalChronicle.create!(
      region_id: 10,
      occurred_at: Time.current,
      job_type: "scavenger:regional:default",
      idempotency_key: "regional-default-#{SecureRandom.hex(6)}",
    )

    assert_equal ScavengerRegionalChronicleEvent::NOTHING, record.reload.event_id
    assert_equal ScavengerRegionalChronicleStatus::NOTHING, record.status_id
  end

  test "enforces region-scoped idempotency uniqueness" do
    key = "regional-unique-#{SecureRandom.hex(6)}"

    ScavengerRegionalChronicle.create!(
      region_id: 1,
      occurred_at: Time.current,
      job_type: "scavenger:regional:unique",
      idempotency_key: key,
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      ScavengerRegionalChronicle.create!(
        region_id: 1,
        occurred_at: Time.current,
        job_type: "scavenger:regional:unique",
        idempotency_key: key,
      )
    end

    assert_nothing_raised do
      ScavengerRegionalChronicle.create!(
        region_id: 2,
        occurred_at: Time.current,
        job_type: "scavenger:regional:unique",
        idempotency_key: key,
      )
    end
  end

  test "rejects non-existent lookup ids by foreign key" do
    connection = ScavengerRegionalChronicle.connection
    now = Time.current

    assert_raises(ActiveRecord::InvalidForeignKey) do
      connection.execute(
        <<~SQL.squish,
          INSERT INTO scavenger_regional_chronicles
          (region_id, occurred_at, event_id, status_id, job_type, idempotency_key, created_at, updated_at)
          VALUES
          (99, #{connection.quote(now)}, 999999, 999999, 'scavenger:regional:fk',
           #{connection.quote("regional-fk-#{SecureRandom.hex(6)}")},
           #{connection.quote(now)}, #{connection.quote(now)})
        SQL
      )
    end
  end
end
