# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyFinalCommitter
  Commit = Data.define(:transaction, :result, :identity, :user, :existing_account, :pt, :entry)

  def self.call!(result_token:, auth_hash: nil, actor: nil, session_ref:, surface:,
                 ip_address: nil, user_agent: nil, now: Time.current)
    new(
      result_token: result_token,
      auth_hash: auth_hash,
      actor: actor,
      session_ref: session_ref,
      surface: surface,
      ip_address: ip_address,
      user_agent: user_agent,
      now: now,
    ).call!
  end

  def initialize(result_token:, auth_hash:, actor:, session_ref:, surface:, ip_address: nil, user_agent: nil,
                 now: Time.current)
    @result_token = result_token
    @auth_hash = auth_hash
    @actor = actor
    @session_ref = session_ref.to_s
    @surface = surface.to_s
    @ip_address = ip_address
    @user_agent = user_agent
    @now = now
  end

  def call!
    validate_binding!
    validate_provider_subject!
    validate_transaction_state!
    consumption = IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: now).call(result_token)
    return commit_login!(consumption) if operation == "login"
    return commit_signup!(consumption) if operation == "signup"

    identity = commit_link!
    record_audit!(identity)
    Commit.new(
      transaction: consumption.transaction,
      result: consumption.result,
      identity: identity,
      user: actor,
      existing_account: nil,
      pt: transaction_return_to,
      entry: nil,
    )
  end

  private

  attr_reader :result_token, :auth_hash, :actor, :session_ref, :surface, :ip_address, :user_agent, :now

  def validate_binding!
    raise IdentitySocialCeremonyContract::Error, "session_ref is required" if session_ref.blank?

    if operation == "link"
      raise IdentitySocialCeremonyContract::Error, "actor is required" if actor.blank?
      unless result["actor_ref"].to_s == actor.public_id.to_s
        raise IdentitySocialCeremonyContract::Error, "result actor does not match current actor"
      end
    elsif result["actor_ref"].to_s != transaction.actor_ref.to_s
      raise IdentitySocialCeremonyContract::Error, "result actor does not match transaction"
    end
    raise IdentitySocialCeremonyContract::Error,
          "result session does not match current session" unless result["session_ref"].to_s == session_ref
    raise IdentitySocialCeremonyContract::Error,
          "result surface does not match current surface" unless result["surface"].to_s == surface
  end

  def validate_provider_subject!
    expected = IdentitySocialCeremonyContract.provider_subject_digest(provider: provider, subject: provider_subject)
    raise IdentitySocialCeremonyContract::Error,
          "result provider subject does not match callback" unless result["provider_subject_digest"].to_s ==
            expected
  end

  def validate_transaction_state!
    raise IdentitySocialCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentitySocialCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
  end

  def commit_link!
    # On the acme completion path the raw provider auth_hash is not replayed
    # to the committer; it is recovered from the one-shot candidate the sign
    # callback stored. Use auth_hash_for_subject so the provider token,
    # refresh token, and expiry are persisted on the linked identity.
    SocialAuthLinkHandler.call(
      auth_hash: auth_hash_for_subject,
      current_client: actor,
      identity_class: identity_class,
      provider: provider,
      uid: provider_subject,
    )[:identity]
  end

  def commit_login!(consumption)
    candidate = IdentitySocialCeremonyCandidateStore.consume!(result["candidate_ref"])
    validate_candidate!(candidate)
    decision = SocialAuthService.handle_callback(
      auth_hash: candidate.auth_hash,
      intent: "login",
      sign_up_entry: transaction_return_entry == "sign_up",
    )
    Commit.new(
      transaction: consumption.transaction,
      result: consumption.result,
      identity: decision[:identity],
      user: decision[:user],
      existing_account: decision[:existing_account],
      pt: transaction_return_to,
      entry: transaction_return_entry,
    )
  end

  def commit_signup!(consumption)
    candidate = IdentitySocialCeremonyCandidateStore.consume!(result["candidate_ref"])
    validate_candidate!(candidate)
    birthdate = result["birthdate"].to_s
    raise IdentitySocialCeremonyContract::Error, "birthdate is required" if birthdate.blank?
    raise IdentitySocialCeremonyContract::Error, "birthdate is ineligible" unless
      AgeEligibility.minimum_age_reached?(birthdate, minimum_age: 13, today: Time.zone.today)

    signup = SocialAuthSignupFinalizer.call(auth_hash: candidate.auth_hash, birthdate: birthdate)
    Commit.new(
      transaction: consumption.transaction,
      result: consumption.result,
      identity: signup.fetch(:identity),
      user: signup.fetch(:user),
      existing_account: false,
      pt: transaction_return_to,
      entry: transaction_return_entry,
    )
  end

  def validate_candidate!(candidate)
    raise IdentitySocialCeremonyContract::Error, "result candidate is required" if candidate.blank?
    raise IdentitySocialCeremonyContract::Error,
          "result candidate digest does not match" unless result["candidate_digest"].to_s == candidate.digest
    raise IdentitySocialCeremonyContract::Error,
          "candidate surface does not match" unless candidate.surface.to_s == surface
    raise IdentitySocialCeremonyContract::Error,
          "candidate actor does not match" unless candidate.actor_ref.to_s == result["actor_ref"].to_s
    raise IdentitySocialCeremonyContract::Error,
          "candidate session does not match" unless candidate.session_ref.to_s == session_ref
    raise IdentitySocialCeremonyContract::Error,
          "candidate transaction does not match" unless candidate.transaction_id.to_s ==
            transaction.transaction_id.to_s
    raise IdentitySocialCeremonyContract::Error,
          "candidate operation does not match" unless candidate.operation.to_s == operation
    raise IdentitySocialCeremonyContract::Error,
          "candidate provider does not match" unless candidate.provider.to_s == provider
  end

  def record_audit!(identity)
    return if identity.blank?

    Rails.logger.info(
      JitLogEvent.format(
        "identity.social_ceremony.link_committed",
        user_id: actor.id,
        provider: SocialIdentifiable.normalize_provider(provider),
      ),
    )
  end

  def result
    @result ||= IdentitySocialCeremonyResult.decode(
      result_token,
      issuer_id: IdentitySocialCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  def transaction
    @transaction ||= IdentitySocialCeremonyReplayStore.for(surface).find_transaction!(result["transaction_id"])
  end

  def provider
    @provider ||= result["provider"].to_s
  end

  def provider_subject
    @provider_subject ||= SocialAuthUidExtractor.call(auth_hash: auth_hash_for_subject).to_s
  end

  def identity_class
    SocialIdentifiable.model_for_provider(provider)
  end

  def operation
    @operation ||= result["operation"].to_s
  end

  def auth_hash_for_subject
    return auth_hash if auth_hash.present?

    candidate_for_subject.auth_hash
  end

  def candidate_for_subject
    @candidate_for_subject ||= IdentitySocialCeremonyCandidateStore.fetch!(result["candidate_ref"])
  end

  def transaction_return_to
    transaction.respond_to?(:return_to) ? transaction.return_to.presence : nil
  end

  def transaction_return_entry
    transaction.respond_to?(:resource_ref) ? transaction.resource_ref.presence : nil
  end
end
