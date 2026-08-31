# typed: false
# frozen_string_literal: true

require "test_helper"

# Bulk rotation counts what it could not rewrite as well as what it could, so an
# operator running an emergency rotation sees the residue rather than a clean
# report. The token and cycle lookups alongside it answer nothing rather than
# raising when the thing they were asked about does not resolve.
class RotationCountingAndTokenActorTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities, :client_token_kinds, :client_token_statuses

  test "a rotation reports the records it could not rewrite alongside the ones it could" do
    client = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    2.times do
      ClientToken.create!(
        user_id: client.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB, discarded_at: 1.day.from_now,
      )
    end
    scope = ClientToken.where(user_id: client.id)
    target = { digest_column: :address_digest }

    all_failed = IdentifierHmacEmergencyRotation.new
    all_failed.define_singleton_method(:overwrite_record) { |*| false }
    failed_counts = all_failed.send(:overwrite_target_records, target, scope)

    assert_equal 0, failed_counts.fetch(:updated)
    assert_equal 2, failed_counts.fetch(:failed),
                 "a record that could not be rewritten has to be counted, not dropped from the report"

    all_updated = IdentifierHmacEmergencyRotation.new
    all_updated.define_singleton_method(:overwrite_record) { |*| true }
    updated_counts = all_updated.send(:overwrite_target_records, target, scope)

    assert_equal 2, updated_counts.fetch(:updated)
    assert_equal 0, updated_counts.fetch(:failed)
  end

  # The actor column differs per surface, and a token that names none is a token
  # this issuer cannot attribute -- answered as nothing rather than guessed at.
  test "a token's actor column is read per surface and answered as nothing when it names none" do
    issuer = AcmeRefreshTokenIssuer.new("raw-token")

    assert_equal :user_id, issuer.send(:actor_identifier_column, Struct.new(:user_id).new(1))
    assert_equal :staff_id, issuer.send(:actor_identifier_column, Struct.new(:staff_id).new(1))
    assert_equal :visitor_id, issuer.send(:actor_identifier_column, Struct.new(:visitor_id).new(1))
    assert_nil issuer.send(:actor_identifier_column, Object.new)
    assert_nil issuer.send(:actor_identifier, Object.new)
    assert_equal 1, issuer.send(:actor_identifier, Struct.new(:user_id).new(1))
  end

  # A stored locator whose payload is missing a key it needs is treated as no
  # cycle at all, rather than raising out of a before_action.
  test "a locator payload missing a key resolves to no cycle rather than raising" do
    locator = SignInCycleLocator.new({ app_sign_in_flow_locator: { "public_id" => "x" } }, surface: :app)

    assert_nil locator.current

    empty = SignInCycleLocator.new({}, surface: :app)

    assert_nil empty.current
  end
end
