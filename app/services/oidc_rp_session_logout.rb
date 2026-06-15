# typed: false
# frozen_string_literal: true

class OidcRpSessionLogout < ApplicationService
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

  def initialize(resource_type:, sid:, reason:)
    super()
    @resource_type = resource_type
    @sid = sid
    @reason = reason
  end

  def call
    return false unless UUID_PATTERN.match?(sid.to_s)
    return false unless token_class.column_names.include?("oidc_sid")

    token = token_class.currently_usable_at.find_by(oidc_sid: sid)
    return false unless token

    AuthenticationLogoutCurrentSession.call(
      resource: token_resource(token),
      token: token,
      token_class: token_class,
      session_public_id: token.oidc_sid,
      reason: reason,
    )
    true
  end

  private

  attr_reader :resource_type, :sid, :reason

  def token_class
    case resource_type.to_s
    when "operator", "staff" then OperatorToken
    when "visitor", "customer" then VisitorToken
    else ClientToken
    end
  end

  def token_resource(token)
    case token
    when OperatorToken then token.operator
    when VisitorToken then token.visitor
    else token.client
    end
  end
end
