# typed: false
# frozen_string_literal: true

class SignSecretRotate
  Result = Struct.new(:secret_credential, :raw_secret_credential, keyword_init: true)

  def self.call(credential_collection:, secret_credential_class:, secret_credential:, name:, secret_kind:,
                usage_policy:, legacy_attributes: {}, delivery_method: nil, scope: nil, max_uses: nil,
                max_failures: nil, not_before_at: nil, issued_at: Time.current, issued_by_type: nil,
                issued_by_id: nil, issued_by_ref: nil)
    new(
      credential_collection: credential_collection,
      secret_credential_class: secret_credential_class,
      secret_credential: secret_credential,
      name: name,
      secret_kind: secret_kind,
      usage_policy: usage_policy,
      legacy_attributes: legacy_attributes,
      delivery_method: delivery_method,
      scope: scope,
      max_uses: max_uses,
      max_failures: max_failures,
      not_before_at: not_before_at,
      issued_at: issued_at,
      issued_by_type: issued_by_type,
      issued_by_id: issued_by_id,
      issued_by_ref: issued_by_ref,
    ).call
  end

  def initialize(credential_collection:, secret_credential_class:, secret_credential:, name:, secret_kind:,
                 usage_policy:, legacy_attributes:, delivery_method:, scope:, max_uses:, max_failures:,
                 not_before_at:, issued_at:, issued_by_type:, issued_by_id:, issued_by_ref:)
    @credential_collection = credential_collection
    @secret_credential_class = secret_credential_class
    @secret_credential = secret_credential
    @name = name
    @secret_kind = secret_kind
    @usage_policy = usage_policy
    @legacy_attributes = legacy_attributes
    @delivery_method = delivery_method
    @scope = scope
    @max_uses = max_uses
    @max_failures = max_failures
    @not_before_at = not_before_at
    @issued_at = issued_at
    @issued_by_type = issued_by_type
    @issued_by_id = issued_by_id
    @issued_by_ref = issued_by_ref
  end

  def call
    rotated = SignSecretIssue.call(
      credential_collection: @credential_collection,
      secret_credential_class: @secret_credential_class,
      name: @name,
      secret_kind: @secret_kind,
      usage_policy: @usage_policy,
      legacy_attributes: @legacy_attributes,
      delivery_method: @delivery_method,
      scope: @scope,
      max_uses: @max_uses,
      max_failures: @max_failures,
      not_before_at: @not_before_at,
      issued_at: @issued_at,
      issued_by_type: @issued_by_type,
      issued_by_id: @issued_by_id,
      issued_by_ref: @issued_by_ref,
    )

    SignSecretRevoke.call(secret_credential: @secret_credential, now: @issued_at)

    Result.new(secret_credential: rotated.secret_credential, raw_secret_credential: rotated.raw_secret_credential)
  end
end
