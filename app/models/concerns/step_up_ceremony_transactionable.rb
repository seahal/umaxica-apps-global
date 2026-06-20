# typed: false
# frozen_string_literal: true

module StepUpCeremonyTransactionable
  extend ActiveSupport::Concern

  STATUS_PENDING = "pending"
  STATUS_CONSUMED = "consumed"
  STATUS_CANCELED = "canceled"
  STATUSES = [STATUS_PENDING, STATUS_CONSUMED, STATUS_CANCELED].freeze
  RETENTION_PERIOD = 7.days

  included do
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    class_attribute :ceremony_surface_name, instance_accessor: false
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    scope :expired_at, ->(time) { where(arel_table[:expires_at].lteq(time)) }
    scope :consumed, -> { where.not(consumed_at: nil).or(where(status: STATUS_CONSUMED)) }
    scope :canceled, -> { where(status: STATUS_CANCELED) }
    scope :active_at, ->(time) {
      where(arel_table[:expires_at].gt(time)).where(consumed_at: nil, status: STATUS_PENDING)
    }
    scope :pending, -> { where(status: STATUS_PENDING, consumed_at: nil) }
    scope :purgeable_at, lambda { |time, retention_period: RETENTION_PERIOD|
      cutoff = time - retention_period
      where(arel_table[:expires_at].lteq(cutoff))
        .or(where(arel_table[:consumed_at].lteq(cutoff)))
    }

    validates :transaction_id, :surface, :actor_ref, :session_ref, :required_scope, :required_aal, :status,
              :grant_jti, :expires_at, presence: true
    validates :transaction_id, uniqueness: true
    validates :grant_jti, uniqueness: true
    validates :result_jti, uniqueness: true, allow_nil: true
    validates :allowed_methods, presence: true
    validates :surface, inclusion: { in: IdentityStepUpCeremonyContract::SURFACES }
    validates :required_aal, inclusion: { in: IdentityStepUpCeremonyContract::AALS }
    validates :aal, inclusion: { in: IdentityStepUpCeremonyContract::AALS }, allow_blank: true
    validates :method, inclusion: { in: IdentityStepUpCeremonyContract::METHODS }, allow_blank: true
    validates :status, inclusion: { in: STATUSES }
    validate :surface_matches_transaction_class
    validate :allowed_methods_are_valid
    validate :consumed_transaction_has_result
  end

  class_methods do
    def ceremony_surface(value = nil)
      self.ceremony_surface_name = value.to_s if value
      ceremony_surface_name
    end

    def create_transaction!(surface: ceremony_surface, actor_ref:, session_ref:, required_scope:, required_aal:,
                            allowed_methods:, resource_ref: nil, return_to: nil, transaction_id: nil,
                            grant_jti: nil, expires_at: nil, now: Time.current)
      connection_owner.connected_to(role: :writing) do
        create!(
          transaction_id: transaction_id.presence || SecureRandom.uuid,
          surface: surface.to_s,
          actor_ref: actor_ref,
          session_ref: session_ref,
          required_scope: required_scope.to_s,
          required_aal: required_aal.to_s,
          allowed_methods: serialize_allowed_methods(allowed_methods),
          resource_ref: resource_ref,
          return_to: return_to,
          grant_jti: grant_jti.presence || SecureRandom.uuid,
          expires_at: expires_at || (now + IdentityStepUpCeremonyTransaction::DEFAULT_TTL),
          created_at: now,
          updated_at: now,
        )
      end
    end

    def latest_pending_for(actor_ref:, session_ref:, required_scope:, now: Time.current)
      pending
        .where(actor_ref: actor_ref, session_ref: session_ref, required_scope: required_scope.to_s)
        .where(arel_table[:expires_at].gt(now))
        .order(created_at: :desc, id: :desc)
        .first
    end

    def serialize_allowed_methods(methods)
      list = Array(methods).map(&:to_s)
      list.uniq!
      list.join(",")
    end

    def connection_owner
      if self <= AppTicketRecord
        AppTicketRecord
      elsif self <= OrgTicketRecord
        OrgTicketRecord
      elsif self <= ComTicketRecord
        ComTicketRecord
      else
        ActiveRecord::Base
      end
    end
  end

  def grant_claims(now: Time.current)
    {
      "surface" => surface,
      "actor_ref" => actor_ref,
      "session_ref" => session_ref,
      "transaction_id" => transaction_id,
      "jti" => grant_jti,
      "required_scope" => required_scope,
      "required_aal" => required_aal,
      "allowed_methods" => allowed_methods_array,
      "resource_ref" => resource_ref,
      "return_to" => return_to,
      "exp" => expires_at.to_i,
      "iat" => now.to_i,
    }.compact
  end

  def allowed_methods_array
    allowed_methods.to_s.split(",").filter_map(&:presence)
  end

  def expired?(now: Time.current)
    expires_at.to_i <= now.to_i
  end

  def consumed? = status == STATUS_CONSUMED
  def canceled? = status == STATUS_CANCELED

  def cancel!(canceled_at: Time.current)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        return locked if locked.canceled? || locked.consumed? || locked.expired?(now: canceled_at)

        locked.update!(status: STATUS_CANCELED, updated_at: canceled_at)
        locked
      end
    end
  end

  def consume_result!(result_jti:, method:, aal:, verified_at:, consumed_at: Time.current)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        raise IdentityStepUpCeremonyContract::Error, "transaction is already consumed" if locked.consumed?
        raise IdentityStepUpCeremonyContract::Error, "transaction is expired" if locked.expired?(now: consumed_at)

        locked.update!(
          result_jti: result_jti,
          method: method,
          aal: aal,
          verified_at: verified_at,
          consumed_at: consumed_at,
          status: STATUS_CONSUMED,
        )
        locked
      end
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    raise IdentityStepUpCeremonyContract::Error, "result_jti has already been consumed: #{e.message}"
  end

  private

  def surface_matches_transaction_class
    return if self.class.ceremony_surface.blank? || surface == self.class.ceremony_surface

    errors.add(:surface, "does not match transaction store")
  end

  def allowed_methods_are_valid
    invalid = allowed_methods_array - IdentityStepUpCeremonyContract::METHODS
    errors.add(:allowed_methods, "contains invalid methods") if invalid.present?
  end

  def consumed_transaction_has_result
    return unless status == STATUS_CONSUMED

    errors.add(:result_jti, "is required for consumed transaction") if result_jti.blank?
    errors.add(:method, "is required for consumed transaction") if method.blank?
    errors.add(:aal, "is required for consumed transaction") if aal.blank?
    errors.add(:verified_at, "is required for consumed transaction") if verified_at.blank?
  end
end
