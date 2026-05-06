# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_contact_chronicles
# Database name: chronicle
#
#  id           :bigint           not null, primary key
#  actor_type   :string
#  expires_at   :datetime
#  occurred_at  :datetime
#  subject_type :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  actor_id     :bigint
#  event_id     :bigint           not null
#  level_id     :bigint           not null
#  subject_id   :bigint           not null
#
# Indexes
#
#  index_org_contact_chronicles_on_actor_type_and_actor_id      (actor_type,actor_id)
#  index_org_contact_chronicles_on_event_id                     (event_id)
#  index_org_contact_chronicles_on_level_id                     (level_id)
#  index_org_contact_chronicles_on_subject_id                   (subject_id)
#  index_org_contact_chronicles_on_subject_type_and_subject_id  (subject_type,subject_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => org_contact_chronicle_events.id)
#  fk_rails_...  (level_id => org_contact_chronicle_levels.id)
#
class OrgContactChronicle < ChronicleRecord
  include Behavior

  belongs_to :org_contact, optional: true, foreign_key: :subject_id, inverse_of: :org_contact_chronicles
  belongs_to :org_contact_chronicle_level, foreign_key: :level_id, inverse_of: :org_contact_chronicles
  belongs_to :org_contact_chronicle_event,
             class_name: "OrgContactChronicleEvent",
             foreign_key: "event_id",
             primary_key: "id",
             inverse_of: :org_contact_chronicles

  validates :event_id, numericality: { only_integer: true }, allow_nil: true
  validates :level_id, numericality: { only_integer: true }, allow_nil: true

  def org_contact
    subject if subject_type == "OrgContact"
  end

  def org_contact=(contact)
    self.subject = contact
  end
end
