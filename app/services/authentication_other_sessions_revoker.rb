# typed: false
# frozen_string_literal: true

# "Revoke every session except the one making this request."
#
# Composed over `AuthenticationSelectedSessionRevoker` so the three browser
# surfaces share one definition of what revoking a single selected session
# means. The current session is skipped by the single-session primitive
# itself (it returns a `:current_session` failure), so callers do not need to
# filter the scope before handing it over.
class AuthenticationOtherSessionsRevoker
  def self.call(...)
    new(...).call
  end

  def initialize(owner:, sessions:, current_token: nil, current_session_public_id: nil,
                 reason: "settings.session.revoke_others")
    @owner = owner
    @sessions = sessions
    @current_token = current_token
    @current_session_public_id = current_session_public_id
    @reason = reason
  end

  def call
    revoked = []

    sessions.find_each do |token|
      result = AuthenticationSelectedSessionRevoker.call(
        owner: owner,
        token: token,
        current_token: current_token,
        current_session_public_id: current_session_public_id,
        reason: reason,
      )
      revoked.concat(result.revoked_tokens) if result.success?
    end

    LogoutResult.success(revoked_tokens: revoked, message: :other_sessions_revoked)
  end

  private

  attr_reader :owner, :sessions, :current_token, :current_session_public_id, :reason
end
