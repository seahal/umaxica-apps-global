# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: chronicles
# Database name: chronicle
#
#  id                            :bigint           not null, primary key
#  action                        :string           not null
#  actor_type                    :string
#  changeset                     :jsonb            not null
#  erasable_at                   :datetime
#  event_uuid                    :string           not null
#  ip_address                    :inet
#  metadata                      :jsonb            not null
#  occurred_at                   :datetime         not null
#  reason                        :string
#  result                        :string           not null
#  subject_type                  :string
#  user_agent                    :text
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  actor_id                      :bigint
#  chronicle_retention_policy_id :bigint           not null
#  request_id                    :string
#  subject_id                    :bigint
#
# Indexes
#
#  index_chronicles_on_action                         (action)
#  index_chronicles_on_actor                          (actor_type,actor_id)
#  index_chronicles_on_chronicle_retention_policy_id  (chronicle_retention_policy_id)
#  index_chronicles_on_erasable_at                    (erasable_at)
#  index_chronicles_on_event_uuid                     (event_uuid) UNIQUE
#  index_chronicles_on_occurred_at                    (occurred_at)
#  index_chronicles_on_request_id                     (request_id)
#  index_chronicles_on_result                         (result)
#  index_chronicles_on_subject                        (subject_type,subject_id)
#
# Foreign Keys
#
#  fk_rails_...  (chronicle_retention_policy_id => chronicle_retention_policies.id)
#
class Chronicle < ChronicleRecord
  include ChronicleCapturable

  RESULTS = %w(intent succeeded failed audit_incomplete invalidated manual_recovery_required).freeze
  MAX_ACTION_LENGTH = 128
  MAX_RESULT_LENGTH = 64
  MAX_REASON_LENGTH = 512
  MAX_REQUEST_ID_LENGTH = 255
  MAX_USER_AGENT_LENGTH = 1024
  MAX_JSON_BYTES = 16.kilobytes

  belongs_to :actor, polymorphic: true, optional: true
  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :chronicle_retention_policy
  has_many :chronicle_visibilities, dependent: :restrict_with_error, inverse_of: :chronicle
  has_many :chronicle_visibility_contexts, through: :chronicle_visibilities

  validates :event_uuid, presence: true, uniqueness: true
  validates :action, presence: true, length: { maximum: MAX_ACTION_LENGTH }
  validates :result, presence: true, inclusion: { in: RESULTS }, length: { maximum: MAX_RESULT_LENGTH }
  validates :reason, length: { maximum: MAX_REASON_LENGTH }, allow_nil: true
  validates :request_id, length: { maximum: MAX_REQUEST_ID_LENGTH }, allow_nil: true
  validates :user_agent, length: { maximum: MAX_USER_AGENT_LENGTH }, allow_nil: true
  validates :occurred_at, presence: true
  validates :metadata, exclusion: { in: [nil] }
  validates :changeset, exclusion: { in: [nil] }
  validate :json_payloads_within_limit
  validate :erasable_at_matches_retention_policy

  before_validation :sanitize_json_payloads

  private

  def sanitize_json_payloads
    self.metadata = ChronicleRecorder.sanitize(metadata || {})
    self.changeset = ChronicleRecorder.sanitize(changeset || {})
    self.reason = ChronicleRecorder.sanitize_text(reason)
  end

  def erasable_at_matches_retention_policy
    return if chronicle_retention_policy.blank?

    if chronicle_retention_policy.permanent?
      errors.add(:erasable_at, "must be nil for permanent retention") if erasable_at.present?
    elsif erasable_at.blank?
      errors.add(:erasable_at, "must be present for non-permanent retention")
    end
  end

  def json_payloads_within_limit
    validate_json_payload_size(:metadata, metadata)
    validate_json_payload_size(:changeset, changeset)
  end

  def validate_json_payload_size(attribute, value)
    size = JSON.generate(value || {}).bytesize
    return if size <= MAX_JSON_BYTES

    errors.add(attribute, "is too large")
  end
end
