# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: scavenger_global_chronicles
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
#  status_id       :bigint           default(0), not null
#
# Indexes
#
#  index_scavenger_global_chronicles_on_event_id         (event_id)
#  index_scavenger_global_chronicles_on_idempotency_key  (idempotency_key) UNIQUE
#  index_scavenger_global_chronicles_on_job_type         (job_type)
#  index_scavenger_global_chronicles_on_occurred_at      (occurred_at)
#  index_scavenger_global_chronicles_on_status_id        (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => scavenger_global_chronicle_events.id)
#  fk_rails_...  (status_id => scavenger_global_chronicle_statuses.id)
#
class ScavengerGlobalChronicle < ChronicleRecord
  belongs_to :scavenger_global_chronicle_status,
             class_name: "ScavengerGlobalChronicleStatus",
             foreign_key: "status_id",
             primary_key: "id",
             inverse_of: :scavenger_global_chronicles
  belongs_to :scavenger_global_chronicle_event,
             class_name: "ScavengerGlobalChronicleEvent",
             foreign_key: "event_id",
             primary_key: "id",
             inverse_of: :scavenger_global_chronicles

  validates :event_id, numericality: { only_integer: true }, allow_nil: true
  validates :status_id, numericality: { only_integer: true }, allow_nil: true
  validates :job_type, presence: true, length: { maximum: 64 }
  validates :idempotency_key, presence: true, length: { maximum: 128 }, uniqueness: true
end
