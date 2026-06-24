# typed: false
# frozen_string_literal: true

class RecoveryPasscodeTopUp
  TARGET_ACTIVE_RECOVERY_PASSCODES = 10

  Result = Struct.new(
    :new_credentials,
    :raw_values,
    :issued_count,
    :active_usable_count_before,
    :active_usable_count_after,
    :target_count,
    keyword_init: true,
  )

  def self.call(actor:, credential_class:, target_count: TARGET_ACTIVE_RECOVERY_PASSCODES, now: Time.current)
    new(actor: actor, credential_class: credential_class, target_count: target_count, now: now).call
  end

  def initialize(actor:, credential_class:, target_count:, now:)
    @actor = actor
    @credential_class = credential_class
    @target_count = target_count.to_i
    @now = now
  end

  def call
    return empty_result(active_usable_count_before: 0) unless supported_recovery_passcode_kind?

    active_usable_count_before = current_active_usable_count
    shortfall = @target_count - active_usable_count_before
    issue_count = [shortfall, available_headroom].min
    return empty_result(active_usable_count_before:) if issue_count <= 0

    new_credentials = []
    raw_values = []

    issue_count.times do
      issued = issue_recovery_passcode!
      new_credentials << issued.secret_credential
      raw_values << issued.raw_secret_credential
    end

    Result.new(
      new_credentials: new_credentials,
      raw_values: raw_values,
      issued_count: issue_count,
      active_usable_count_before: active_usable_count_before,
      active_usable_count_after: active_usable_count_before + issue_count,
      target_count: @target_count,
    )
  end

  private

  attr_reader :actor, :credential_class, :now

  def empty_result(active_usable_count_before:)
    Result.new(
      new_credentials: [],
      raw_values: [],
      issued_count: 0,
      active_usable_count_before: active_usable_count_before,
      active_usable_count_after: active_usable_count_before,
      target_count: @target_count,
    )
  end

  def supported_recovery_passcode_kind?
    recovery_kind_id.present?
  end

  def recovery_kind_id
    credential_class.const_get(:RECOVERY)
  rescue NameError
    nil
  end

  def current_active_usable_count
    SignRecoveryPasscodeRequirement.usable_unused_count(
      actor: actor,
      credential_class: credential_class,
      now: now,
    )
  end

  def available_headroom
    limit = max_secret_count_limit
    return Float::INFINITY if limit.blank?

    [limit - total_secret_count, 0].max
  end

  def max_secret_count_limit
    case credential_class.name
    when "ClientSecretCredential"
      credential_class::MAX_SECRETS_PER_USER
    when "VisitorSecretCredential"
      credential_class::MAX_SECRETS_PER_VISITOR
    when "OperatorSecretCredential"
      credential_class::MAX_SECRETS_PER_STAFF
    end
  rescue NameError
    nil
  end

  def total_secret_count
    secret_credential_relation.count
  end

  def secret_credential_relation
    case credential_class.name
    when "ClientSecretCredential"
      actor.client_secret_credentials
    when "VisitorSecretCredential"
      actor.visitor_secret_credentials
    when "OperatorSecretCredential"
      actor.staff_secret_credentials
    else
      raise ArgumentError, "unsupported recovery passcode credential class: #{credential_class.name}"
    end
  end

  def issue_recovery_passcode!
    credential_collection = secret_credential_relation
    credential_class.transaction do
      SignSecretIssue.call(
        credential_collection: credential_collection,
        secret_credential_class: credential_class,
        name: "Recovery #{credential_collection.count + 1}",
        secret_kind: :recovery,
        usage_policy: :single_use,
        legacy_attributes: recovery_passcode_legacy_attributes,
        issued_at: now,
      )
    end
  end

  def recovery_passcode_legacy_attributes
    attrs = {}
    kind_column = recovery_kind_column
    attrs[kind_column] = recovery_kind_id if kind_column.present?
    status_column = credential_class.identity_secret_credential_status_id_column
    attrs[status_column] = active_status_id if status_column.present? && active_status_id.present?
    attrs[:uses_remaining] = 1 if credential_class.column_names.include?("uses_remaining")
    attrs
  end

  def recovery_kind_column
    case credential_class.name
    when "ClientSecretCredential"
      :user_secret_kind_id
    when "VisitorSecretCredential"
      :visitor_secret_credential_kind_id
    when "OperatorSecretCredential"
      :staff_secret_kind_id
    end
  end

  def active_status_id
    credential_class.identity_secret_credential_status_class.const_get(:ACTIVE)
  rescue NameError
    nil
  end
end
