# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: chronicle_outbox_entries
# Database name: chronicle
#
#  id           :bigint           not null, primary key
#  event        :string           not null
#  event_uuid   :string           not null
#  payload      :jsonb            not null
#  status       :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  chronicle_id :bigint
#  request_id   :string
#
# Indexes
#
#  index_chronicle_outbox_entries_on_chronicle_id  (chronicle_id)
#  index_chronicle_outbox_entries_on_event_uuid    (event_uuid)
#  index_chronicle_outbox_entries_on_status        (status)
#
# Foreign Keys
#
#  fk_rails_...  (chronicle_id => chronicles.id)
#
class ChronicleOutboxEntry < ChronicleRecord
  belongs_to :chronicle, optional: true

  validates :event_uuid, presence: true
  validates :event, presence: true, length: { maximum: 128 }
  validates :status, presence: true, length: { maximum: 64 }
  validates :payload, exclusion: { in: [nil] }
end
