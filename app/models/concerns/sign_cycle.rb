# typed: false
# frozen_string_literal: true

module SignCycle
  extend ActiveSupport::Concern

  included do
    include ::PublicId
    include ::Retainable

    self.belongs_to_required_by_default = false

    attribute :issued_at, :datetime, default: -> { Time.current }
    attribute :expires_at, :datetime, default: -> { default_ttl.from_now }

    before_validation :ensure_sign_cycle_status_defaults
    before_validation :assign_default_status_id
    before_validation :sync_legacy_state_from_status

    validates :status_id, presence: true, inclusion: { in: ->(record) { record.class::STATUS_IDS } }
    validates :step, presence: true, inclusion: { in: ->(record) { record.class::STEPS } }
    validates :nonce_digest, presence: true
    validates :issued_at, :expires_at, presence: true
    validate :expires_after_issued_at
    validate :completed_state_has_completed_at

    scope :recent_first, -> { order(created_at: :desc) }
    scope :current,
          -> do
            where(arel_table[:discarded_at].gt(Time.current))
              .where(arel_table[:expires_at].gt(Time.current))
          end
  end

  class_methods do
    def digest_nonce(nonce)
      OpenSSL::Digest::SHA256.hexdigest(nonce.to_s)
    end

    def default_ttl
      15.minutes
    end

    def status_id_for(status_name)
      self::STATUSES.fetch(status_name.to_s)
    end

    def status_name_for(status_id)
      self::STATUS_NAMES.fetch(status_id)
    end

    def status_ids_for(*status_names)
      status_names.map { |status_name| status_id_for(status_name) }
    end

    def completed_status_id
      status_id_for("COMPLETED")
    end
  end

  def default_expires_at
    self.class.default_ttl.from_now
  end

  def expired?(now = Time.current)
    expires_at <= now || lapsed?
  end

  def completed?
    status_id == self.class.completed_status_id
  end

  def nonce_matches?(nonce)
    return false if nonce.blank? || nonce_digest.blank?

    ActiveSupport::SecurityUtils.secure_compare(nonce_digest, self.class.digest_nonce(nonce))
  end

  delegate :status_id_for, to: :class

  delegate :status_name_for, to: :class

  def status_ids_for(*status_names)
    self.class.status_ids_for(*status_names)
  end

  def can_transition_to?(next_status)
    next_status_id = normalize_status_id(next_status)

    self.class::TRANSITIONS.fetch(status_id, []).include?(next_status_id)
  end

  def transition_to!(next_status, step: nil, now: Time.current)
    next_status_id = normalize_status_id(next_status)
    unless can_transition_to?(next_status_id)
      raise ArgumentError, "invalid transition from #{status_id.inspect} to #{next_status_id.inspect}"
    end

    attrs = { status_id: next_status_id }
    attrs[:step] = step if step.present?
    attrs[:completed_at] = now if next_status_id == self.class.completed_status_id
    update!(attrs)
  end

  def discard!(now: Time.current)
    update!(discarded_at: now)
  end

  private

  def normalize_status_id(status)
    return status if status.is_a?(Integer)

    self.class.status_id_for(status)
  end

  def ensure_sign_cycle_status_defaults
    self.class::STATUS_MODEL.ensure_defaults!
  end

  def assign_default_status_id
    self.status_id ||= self.class::STATUS_IDS.first
  end

  def sync_legacy_state_from_status
    return unless has_attribute?(:state)
    return if status_id.blank?

    self.state = self.class::STATUS_NAMES[status_id]
  end

  def expires_after_issued_at
    return if issued_at.blank? || expires_at.blank?
    return if issued_at < expires_at

    errors.add(:expires_at, "must be after issued_at")
  end

  def completed_state_has_completed_at
    return unless completed?

    errors.add(:completed_at, "must be present for completed cycles") if completed_at.blank?
  end
end
