# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityTotpCeremonyTransactionPurgerTest < ActiveSupport::TestCase
  test "deletes purgeable totp ceremony transactions" do
    now = Time.utc(2026, 8, 10, 12, 0, 0)
    retention = TotpCeremonyTransactionable::RETENTION_PERIOD

    stale = ClientTotpCeremonyTransaction.create_transaction!(
      actor_ref: "actor-#{SecureRandom.hex(4)}",
      session_ref: "session-#{SecureRandom.hex(4)}",
      operation: "enrollment",
      expires_at: now - retention - 1.hour,
    )
    fresh = ClientTotpCeremonyTransaction.create_transaction!(
      actor_ref: "actor-#{SecureRandom.hex(4)}",
      session_ref: "session-#{SecureRandom.hex(4)}",
      operation: "enrollment",
      expires_at: now + 1.hour,
    )

    result = IdentityTotpCeremonyTransactionPurger.new(now: now, retention_period: retention).call

    assert_equal({ app: 1 }, result)
    assert_nil ClientTotpCeremonyTransaction.find_by(id: stale.id)
    assert ClientTotpCeremonyTransaction.exists?(fresh.id)
  end
end
