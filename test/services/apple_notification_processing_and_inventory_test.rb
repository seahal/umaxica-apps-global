# typed: false
# frozen_string_literal: true

require "test_helper"

# A notification that names no linked identity has nothing to act on, and an
# inventory asked about no actor has nothing to report. Both answer emptily
# rather than raising, because both are read on paths that must not fail when the
# subject has already been removed.
class AppleNotificationProcessingAndInventoryTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities

  test "a notification naming no linked identity applies nothing" do
    event = ClientAppleNotificationEvent.new(jti: SecureRandom.uuid, event_type: "consent-revoked")
    processor = ExternalAuthenticationAppleNotificationProcessor.new(event: event)

    assert_not processor.send(:apply_consent_revocation!)
    assert_not processor.send(:apply_account_deletion!)
  end

  test "a processor without a notification event at all is refused at construction" do
    assert_raises(ArgumentError) { ExternalAuthenticationAppleNotificationProcessor.new(event: nil) }
  end

  # The inventory is read to decide which factors may still be offered. With no
  # actor it has to report none of each rather than raise, so a signed-out caller
  # is offered nothing rather than seeing an error.
  test "an inventory for no actor reports every list empty" do
    result = AuthenticationCredentialInventory.call(nil)

    assert_nil result.actor
    assert_empty result.aal1_methods
    assert_empty result.aal2_methods
    assert_empty result.aal3_methods
    assert_empty result.contact_identifiers
    assert_empty result.phishing_resistant_methods
  end

  test "an inventory for a real actor reports that actor and a third factor list that is always empty" do
    result = AuthenticationCredentialInventory.call(clients(:one))

    assert_equal clients(:one), result.actor
    assert_empty result.aal3_methods, "no surface issues a third factor yet"
  end

  # Two availability slots claiming the same hostname would leave the switch that
  # answers for it undefined, so the registry refuses to build at all.
  test "a hostname claimed by two availability slots is refused by name" do
    registry = FqdnAvailabilityRegistry.dup
    slot = Struct.new(:name, :hostnames)
    registry.define_singleton_method(:slots) do
      [slot.new(:first, %w(shared.example.test)), slot.new(:second, %w(shared.example.test))]
    end

    error = assert_raises(ArgumentError) { registry.send(:index) }

    assert_match(/claimed by both/, error.message)
  end
end
