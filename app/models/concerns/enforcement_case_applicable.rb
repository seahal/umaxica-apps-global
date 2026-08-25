# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md: shared behaviour for the three per-realm
# Enforcement Case models. Deliberately thin per
# .agents/harnesses/rules/generic/rails-concerns.mdc -- it supplies apply!,
# close-before-apply effect superseding, and the in-force query helpers.
# Each including class supplies its own has_one/has_many associations (the FK
# column name differs per realm) and `principal_class` / `realm`.
module EnforcementCaseApplicable
  extend ActiveSupport::Concern

  KINDS = %w(security_lock cooldown temporary_freeze permanent_ban method_protection).freeze
  STATES = %w(draft pending_approval active ended failed).freeze
  DURATION_MODES = %w(timed indefinite permanent).freeze
  VISIBILITIES = %w(visible hidden).freeze
  RELEASE_MODES = %w(automatic operator verification_required break_glass_only).freeze
  END_REASONS = %w(expired revoked superseded corrected appeal_approved break_glass_released verification_completed).freeze
  ACCESS_BLOCKING_KINDS = %w(temporary_freeze permanent_ban).freeze
  METHOD_REVOKING_EFFECTS = %w(unusable permanently_frozen).freeze

  class ApprovalRequiredError < StandardError; end

  class InvalidStateTransitionError < StandardError; end

  included do
    validates :public_id, presence: true, uniqueness: true, length: { maximum: 21 }
    validates :kind, presence: true, inclusion: { in: KINDS }
    validates :state, presence: true, inclusion: { in: STATES }
    validates :duration_mode, presence: true, inclusion: { in: DURATION_MODES }
    validates :visibility, presence: true, inclusion: { in: VISIBILITIES }
    validates :release_mode, presence: true, inclusion: { in: RELEASE_MODES }
    validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true
    # Reused from AdministrativeAccessLockable rather than redefined: the
    # operational vocabulary for "why did an operator restrict this account"
    # does not change because the scope widened to Unified Enforcement.
    validates :reason_code, presence: true, inclusion: { in: AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES }
    validates :principal_public_id, presence: true
    validates :applied_by_operator_public_id, presence: true
    validates :effective_at, presence: true

    before_validation :assign_public_id, on: :create
  end

  class_methods do
    def in_force
      where(state: "active", ended_at: nil)
        .where("#{table_name}.effective_at <= ?", Time.current)
        .where("#{table_name}.expires_at IS NULL OR #{table_name}.expires_at > ?", Time.current)
    end

    def pending_convergence
      where(state: "active").where("sessions_revoked_at IS NULL OR audited_at IS NULL")
    end

    # adr/unified-enforcement.md, Retention interaction / Purge protection:
    # read by RetentionPurgeJob and WithdrawalPersonalDataAnonymizer so the
    # ordinary purge path raises a clean, explicit skip rather than the
    # database trigger's raw exception. No FK is involved -- a lapsed Case
    # can never answer true here (D7).
    def principal_effect_blocking?(principal_public_id, flag)
      in_force
        .where(principal_public_id: principal_public_id)
        .joins(:principal_effect)
        .merge(reflect_on_association(:principal_effect).klass.where(flag => true))
        .exists?
    end

    # Sign-in-path counterpart to principal_effect_blocking?: is this specific
    # authentication method (not the whole principal) currently revoked.
    # Independent of login_allowed? (BAN), which only sees principal-level
    # status, not per-method effects.
    def authentication_method_effect_blocking?(principal_public_id, authentication_method)
      in_force
        .where(principal_public_id: principal_public_id)
        .joins(:authentication_method_effects)
        .merge(
          reflect_on_association(:authentication_method_effects).klass
            .where(authentication_method: authentication_method)
            .where(effect: METHOD_REVOKING_EFFECTS),
        )
        .exists?
    end
  end

  def in_force?
    return false unless state == "active"
    return false if ended_at.present?
    return false if effective_at.present? && effective_at > Time.current
    return false if expires_at.present? && expires_at <= Time.current

    true
  end

  def open?
    ended_at.nil?
  end

  def requires_approval?
    return true if break_glass?
    # A Case's principal is always the realm's own principal_class -- an org
    # Case's principal is always an Operator, never a Client or Visitor -- so
    # this is a realm check, not a per-row lookup (D12: any permanent_ban
    # targeting an Operator requires approval).
    return true if kind == "permanent_ban" && (visibility == "hidden" || self.class.principal_class == ::Operator)

    false
  end

  # D2: one *_zenith transaction commits the Case + its Effect associations
  # (built but not yet persisted -- via case.build_principal_effect,
  # case.authentication_method_effects.build, etc.) and flips state to
  # active. Effects are never inserted before apply! runs: close-before-apply
  # (D9/D8) must close any conflicting open row *before* the new one is
  # inserted, so the whole sequence -- close, then insert, then activate --
  # is one atomic step. Runtime enforcement reads only the committed row, so
  # the security decision is atomic and fail-closed at commit. Session
  # revocation and the audit write happen after commit; a failure there
  # leaves the Case correctly `active` with sessions_revoked_at / audited_at
  # still nil for the reconciler to find (Failure recovery / Reconciliation)
  # -- it must never roll the Case back to `failed`, because the security
  # decision it already committed remains correct.
  def apply!
    unless %w(draft pending_approval).include?(state)
      raise InvalidStateTransitionError, "Case #{public_id} is already #{state}"
    end
    if requires_approval? && approved_by_operator_public_id.blank?
      raise ApprovalRequiredError, "Case #{public_id} requires approval before it can be applied"
    end

    self.class.transaction do
      close_superseded_effects!
      self.state = "active"
      save!
    end

    perform_principal_access_effect!
    revoke_method_sessions!
    write_audit_event!("applied")

    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    update_column(:state, "failed") if persisted? # rubocop:disable Rails/SkipsModelValidations
    raise e
  end

  # D8: ending a Case closes all its own still-open Effects in the same
  # transaction, and (Administrative Access Lock integration) unlocks the
  # principal only if no other Case's Principal Effect is still in force for
  # them.
  def end_case!(reason:, ended_by_operator_public_id: nil)
    raise ArgumentError, "reason must be one of #{END_REASONS}" unless END_REASONS.include?(reason.to_s)

    now = Time.current
    self.class.transaction do
      update!(ended_at: now, end_reason: reason, ended_by_operator_public_id: ended_by_operator_public_id)
      principal_effect&.update!(ended_at: now)
      authentication_method_effects.where(ended_at: nil).update_all(ended_at: now) # rubocop:disable Rails/SkipsModelValidations
      identifier_effects.where(ended_at: nil).update_all(ended_at: now) # rubocop:disable Rails/SkipsModelValidations
    end

    release_principal_access_effect!
    write_audit_event!((reason == "expired") ? "expired" : "ended")

    true
  end

  def revoke_method_sessions!
    return unless persisted?

    principal = self.class.principal_class.find_by(public_id: principal_public_id)
    return unless principal

    authentication_method_effects.where(ended_at: nil).find_each do |effect|
      next unless METHOD_REVOKING_EFFECTS.include?(effect.effect)

      AuthenticationSessionRevoker.tokens_for_method(principal, effect.authentication_method)
        .not_revoked.find_each(&:revoke!)
    end

    update!(sessions_revoked_at: Time.current)
  end

  def write_audit_event!(event_type)
    ChronicleRecord.connected_to(role: :writing) do
      EnforcementEvent.create!(
        realm: self.class.realm,
        case_public_id: public_id,
        principal_public_id: principal_public_id,
        event_type: event_type,
        reason_code: reason_code,
        operator_public_id: applied_by_operator_public_id,
        break_glass: break_glass,
        ticket_id: ticket_id,
        occurred_at: Time.current,
        metadata: {},
      )
    end
    update!(audited_at: Time.current)
  end

  private

  def assign_public_id
    self.public_id ||= SecureRandom.urlsafe_base64(15)
  end

  # D9: applying a new open effect for a slot another Case still holds open
  # closes the prior row first, in the same transaction, so an expired row
  # can never block a new one and escalation/de-escalation stays atomic with
  # an append-only history.
  def close_superseded_effects!
    close_superseded!(authentication_method_effects, %i(principal_public_id authentication_method))
    close_superseded!(identifier_effects, %i(identifier_kind lookup_digest))
  end

  def close_superseded!(association, key_columns)
    association.select(&:new_record?).each do |effect|
      scope = association.klass.where(ended_at: nil)
      key_columns.each { |column| scope = scope.where(column => effect.public_send(column)) }
      scope.update_all(ended_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def perform_principal_access_effect!
    effect = principal_effect
    return unless effect&.access_blocking?

    principal = self.class.principal_class.find_by!(public_id: principal_public_id)
    operator = ::Operator.find_by!(public_id: applied_by_operator_public_id)

    AdministrativeAccessLock.lock!(
      account: principal,
      operator: operator,
      reason_code: reason_code,
      reason_note: reason_note,
      ticket_id: ticket_id,
      metadata: { enforcement_case_public_id: public_id },
    )
  end

  # Unlocks admin_locked only when no other Case's Principal Effect is still
  # in force for this principal (adr/unified-enforcement.md, Administrative
  # Access Lock integration -- the refcount rule).
  def release_principal_access_effect!
    effect = principal_effect
    return unless effect&.access_blocking?

    other_blocking_case_in_force =
      self.class.in_force
        .where(principal_public_id: principal_public_id)
        .where.not(id: id)
        .joins(:principal_effect)
        .merge(principal_effect.class.where(access_blocking: true))
        .exists?
    return if other_blocking_case_in_force

    principal = self.class.principal_class.find_by(public_id: principal_public_id)
    return unless principal

    operator = ::Operator.find_by(public_id: applied_by_operator_public_id)
    return unless operator

    AdministrativeAccessLock.unlock!(
      account: principal,
      operator: operator,
      reason_code: reason_code,
      ticket_id: ticket_id,
      metadata: { enforcement_case_public_id: public_id },
    )
  end
end
