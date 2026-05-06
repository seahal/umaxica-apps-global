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
class ScavengerRegionalChronicle < ChronicleRecord
  belongs_to :scavenger_regional_chronicle_status,
             class_name: "ScavengerRegionalChronicleStatus",
             foreign_key: "status_id",
             primary_key: "id",
             inverse_of: :scavenger_regional_chronicles
  belongs_to :scavenger_regional_chronicle_event,
             class_name: "ScavengerRegionalChronicleEvent",
             foreign_key: "event_id",
             primary_key: "id",
             inverse_of: :scavenger_regional_chronicles

  validates :event_id, numericality: { only_integer: true }, allow_nil: true
  validates :status_id, numericality: { only_integer: true }, allow_nil: true
  validates :job_type, presence: true, length: { maximum: 64 }
  validates :idempotency_key, presence: true, length: { maximum: 128 }
  validates :region_id, presence: true
  validates :idempotency_key, uniqueness: { scope: :region_id }
end
