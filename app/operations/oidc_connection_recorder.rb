# typed: false
# frozen_string_literal: true

class OidcConnectionRecorder < ApplicationService
  def initialize(resource:, client:, scope:, used_at: Time.current)
    super()
    @resource = resource
    @client = client
    @scope = scope
    @used_at = used_at
  end

  def call
    attributes = { actor_key => resource.id }
    attributes[:client_id] = client.client_id

    connection = connection_model.find_or_initialize_by(attributes)
    connection.scope = normalized_scope
    connection.last_used_at = used_at
    connection.revoked_at = nil
    connection.save!
    connection
  end

  private

  attr_reader :resource, :client, :scope, :used_at

  def connection_model
    case resource
    when Operator then OperatorOidcConnection
    when Visitor then VisitorOidcConnection
    else ClientOidcConnection
    end
  end

  def actor_key
    connection_model.actor_foreign_key
  end

  def normalized_scope
    scope.to_s.split.uniq.join(" ").presence
  end
end
