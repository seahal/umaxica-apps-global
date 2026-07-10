# typed: false
# frozen_string_literal: true

class VisitorSecretCredentialsCreate
  ACTION = "visitor_secret_credential.create"

  Result = Struct.new(:secret_credential, :raw_secret_credential, keyword_init: true)

  def self.call(actor:, visitor:, params:, raw_secret_credential: nil)
    new(actor: actor, visitor: visitor, params: params, raw_secret_credential: raw_secret_credential).call
  end

  def initialize(actor:, visitor:, params:, raw_secret_credential: nil)
    @actor = actor
    @visitor = visitor
    @params = params
    @raw_secret_credential = raw_secret_credential
  end

  def call
    raw_secret_credential = @raw_secret_credential.presence || VisitorSecretCredential.generate_raw_secret_credential
    secret_credential = @visitor.visitor_secret_credentials.new(name: @params[:name].to_s.strip)
    secret_credential.raw_secret_credential = raw_secret_credential
    secret_credential.password = raw_secret_credential
    secret_credential.visitor_secret_credential_status_id = status_id_for(@params[:enabled])

    secret_credential.save!

    Result.new(secret_credential: secret_credential, raw_secret_credential: raw_secret_credential)
  end

  private

  def status_id_for(enabled_param)
    enabled = ActiveModel::Type::Boolean.new.cast(enabled_param)
    status = enabled ? :active : :revoked
    VisitorSecretCredential.status_id_for(status)
  end
end
