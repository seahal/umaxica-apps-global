# typed: false
# frozen_string_literal: true

class ClientAppleCredentialRevocation < AppPrincipalRecord
  RETENTION_PERIOD = 7.days
  MAXIMUM_RETRIES = 10
  STATUSES = %w(pending retrying completed expired).freeze
  REASONS = %w(unlink withdrawal).freeze

  encrypts :refresh_token

  belongs_to :client, inverse_of: :client_apple_credential_revocations

  validates :public_id, presence: true, uniqueness: true
  validates :reason, inclusion: { in: REASONS }
  validates :status, inclusion: { in: STATUSES }
  validates :retry_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :requested_at, :retention_deadline_at, presence: true
  validate :dispatchable_status_requires_refresh_token

  before_validation :assign_defaults, on: :create
  after_create_commit :enqueue_if_dispatchable

  scope :due, ->(now = Time.current) { where(status: %w(pending retrying)).where(next_retry_at: ..now) }

  def self.create_for!(client:, refresh_token:, reason:, now: Time.current)
    token = refresh_token.to_s
    attributes = {
      client: client,
      refresh_token: token,
      reason: reason,
      requested_at: now,
      retention_deadline_at: now + RETENTION_PERIOD,
    }

    if token.blank?
      create!(
        **attributes,
        status: "expired",
        completed_at: now,
        next_retry_at: nil,
        last_failure_code: "credential_unavailable",
      )
    else
      create!(**attributes)
    end
  end

  def terminal?
    %w(completed expired).include?(status)
  end

  def dispatchable?
    !terminal?
  end

  def complete!(now: Time.current)
    update!(status: "completed", completed_at: now, next_retry_at: nil, refresh_token: "", last_failure_code: "")
  end

  def retry_or_expire!(code:, now: Time.current)
    next_count = retry_count + 1
    if next_count >= MAXIMUM_RETRIES || now >= retention_deadline_at
      update!(status: "expired", retry_count: next_count, next_retry_at: nil, refresh_token: "", last_failure_code: code)
      return :expired
    end

    update!(
      status: "retrying",
      retry_count: next_count,
      next_retry_at: now + retry_delay(next_count),
      last_failure_code: code,
    )
    :retrying
  end

  def expire!(code:, now: Time.current)
    update!(
      status: "expired",
      completed_at: now,
      next_retry_at: nil,
      refresh_token: "",
      last_failure_code: code,
    )
  end

  private

  def assign_defaults
    self.public_id ||= SecureRandom.urlsafe_base64(15)
    self.requested_at ||= Time.current
    self.retention_deadline_at ||= requested_at + RETENTION_PERIOD
    self.next_retry_at ||= requested_at
  end

  def dispatchable_status_requires_refresh_token
    return unless dispatchable? && refresh_token.blank?

    errors.add(:refresh_token, "must be present while revocation is pending")
  end

  def enqueue_if_dispatchable
    AppleCredentialRevocationJob.perform_later(public_id) if dispatchable?
  end

  def retry_delay(count)
    [(2**count).minutes, 2.hours].min
  end
end
