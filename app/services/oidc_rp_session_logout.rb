# typed: false
# frozen_string_literal: true

class OidcRpSessionLogout < ApplicationService
  def initialize(resource_type:, sid:, reason:)
    super()
    @resource_type = resource_type
    @sid = sid
    @reason = reason
  end

  def call
    return false unless OidcLogoutTokenCodec::UUID_PATTERN.match?(sid.to_s)

    token = usage_class.currently_usable_at.find_by(public_id: sid)
    token ||= token_class.currently_usable_at.find_by(oidc_sid: sid)
    token ||= token_class.currently_usable_at.find_by(public_id: sid)
    return false unless token

    AuthenticationLogoutCurrentSession.call(
      resource: token_resource(token),
      token: token,
      token_class: token_class,
      session_public_id: token.public_id,
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

  def usage_class
    case resource_type.to_s
    when "operator", "staff" then OperatorTokenUsage
    when "visitor", "customer" then VisitorTokenUsage
    else ClientTokenUsage
    end
  end

  def token_resource(token)
    case token
    when OperatorToken then token.staff
    when VisitorToken then token.visitor
    else token.user
    end
  end
end
