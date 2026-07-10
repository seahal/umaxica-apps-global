# typed: false
# frozen_string_literal: true

class TurnstileReplayStore
  def self.consume!(token:, ceremony_id:, action:, hostname:, cdata:, expires_at:)
    new.consume!(
      token: token,
      ceremony_id: ceremony_id,
      action: action,
      hostname: hostname,
      cdata: cdata,
      expires_at: expires_at,
    )
  end

  def consume!(token:, ceremony_id:, action:, hostname:, cdata:, expires_at:)
    TurnstileReplay.create!(
      ceremony_id: ceremony_id.to_s,
      token_digest: TurnstileReplay.digest_token(token),
      action: action.to_s,
      hostname: hostname.to_s,
      cdata: cdata.to_s,
      expires_at: expires_at,
      consumed_at: Time.current,
    )
    true
  rescue ActiveRecord::RecordNotUnique
    raise
  end
end
