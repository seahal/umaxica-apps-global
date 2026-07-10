# typed: false
# frozen_string_literal: true

class OidcAuthorizationTransactionCoordinator < ApplicationService
  Issuance = Data.define(:transaction, :resume_url)

  def self.model_for(surface)
    case surface.to_s
    when "app" then ClientOidcAuthorizationTransaction
    when "com" then VisitorOidcAuthorizationTransaction
    when "org" then OperatorOidcAuthorizationTransaction
    else
      raise ArgumentError, "unsupported OIDC authorization surface: #{surface.inspect}"
    end
  end

  def self.issue!(surface:, intent:, params:, login_challenge: SecureRandom.urlsafe_base64(32),
                  now: Time.current, login_challenge_ttl: 10.minutes, ttl: 15.minutes)
    transaction =
      model_for(surface).create_transaction!(
        surface: surface,
        intent: intent,
        client_id: params.fetch(:client_id),
        redirect_uri: params.fetch(:redirect_uri),
        response_type: params.fetch(:response_type),
        scope: params.fetch(:scope),
        state: params.fetch(:state),
        nonce: params.fetch(:nonce),
        code_challenge: params.fetch(:code_challenge),
        code_challenge_method: params.fetch(:code_challenge_method),
        login_challenge: login_challenge,
        login_challenge_expires_at: now + login_challenge_ttl,
        expires_at: now + ttl,
        now: now,
      )
    Issuance.new(transaction: transaction, resume_url: transaction.acme_resume_url)
  end

  def self.find_by_login_challenge!(surface:, login_challenge:)
    model_for(surface).find_by!(login_challenge: login_challenge)
  end

  def self.register_result!(surface:, login_challenge:, actor:, session_ref:, auth_method:, acr: nil,
                            now: Time.current)
    transaction = find_by_login_challenge!(surface: surface, login_challenge: login_challenge)
    transaction = transaction.register_authentication!(
      actor_ref: actor.public_id,
      session_ref: session_ref,
      auth_method: auth_method,
      acr: acr,
      now: now,
    )
    Issuance.new(transaction: transaction, resume_url: transaction.acme_resume_url)
  end

  def self.consume!(surface:, login_challenge:, now: Time.current)
    find_by_login_challenge!(surface: surface, login_challenge: login_challenge).consume!(now: now)
  end
end
