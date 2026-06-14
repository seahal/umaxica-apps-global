# typed: false
# frozen_string_literal: true

class SignSecretIssue
  Result = Struct.new(:secret_credential, :raw_secret_credential, keyword_init: true)

  def self.call(credential_collection:, secret_credential_class:, name:, secret_kind:, usage_policy:,
                legacy_attributes: {}, delivery_method: nil, scope: nil, max_uses: nil, max_failures: nil,
                not_before_at: nil, issued_at: Time.current, issued_by_type: nil, issued_by_id: nil,
                issued_by_ref: nil, raw_secret_credential: nil)
    new(
      credential_collection: credential_collection,
      secret_credential_class: secret_credential_class,
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
      raw_secret_credential: raw_secret_credential,
    ).call
  end

  def initialize(credential_collection:, secret_credential_class:, name:, secret_kind:, usage_policy:,
                 legacy_attributes:, delivery_method:, scope:, max_uses:, max_failures:, not_before_at:,
                 issued_at:, issued_by_type:, issued_by_id:, issued_by_ref:, raw_secret_credential:)
    @credential_collection = credential_collection
    @secret_credential_class = secret_credential_class
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
    @raw_secret_credential = raw_secret_credential
  end

  def call
    raise ArgumentError, "limited_session issuance is not enabled yet" if @usage_policy.to_s == "limited_session"

    raw_secret_credential = @raw_secret_credential.presence ||
      @secret_credential_class.generate_raw_secret_credential
    secret_credential = @credential_collection.new(
      @legacy_attributes.merge(
        name: @name.to_s.strip,
        password: raw_secret_credential,
        secret_kind: @secret_kind,
        usage_policy: @usage_policy,
        lookup_digest: SignSecretLookupDigest.digest(raw_secret_credential),
        safe_prefix: raw_secret_credential.first(6),
        issued_at: @issued_at,
        issued_by_type: @issued_by_type,
        issued_by_id: @issued_by_id,
        issued_by_ref: @issued_by_ref,
        delivery_method: @delivery_method,
        scope: @scope,
        use_count: 0,
        failure_count: 0,
        max_uses: @max_uses,
        max_failures: @max_failures,
        not_before_at: @not_before_at,
      ),
    )
    secret_credential.raw_secret_credential = raw_secret_credential if
      secret_credential.respond_to?(:raw_secret_credential=)

    @secret_credential_class.transaction do
      secret_credential.save!
    end

    SignSecretRecordEvent.call(
      event_name: "secret.issued",
      secret_credential: secret_credential,
      details: {
        secret_kind: @secret_kind,
        usage_policy: @usage_policy,
        delivery_method: @delivery_method,
        scope: @scope,
      },
    )

    Result.new(secret_credential: secret_credential, raw_secret_credential: raw_secret_credential)
  end
end
