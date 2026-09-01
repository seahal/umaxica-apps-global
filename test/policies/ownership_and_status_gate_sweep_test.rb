# typed: false
# frozen_string_literal: true

require "test_helper"

# Ownership gates and status gates that decide whether one actor may act on
# another's record. Every arm that answers false is the one keeping a surface's
# accounts and organizations out of another surface's reach, and the checkpoint
# gate is what keeps a sign-in cycle from being advanced from the wrong step.
class OwnershipAndStatusGateSweepTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities, :operators, :operator_statuses

  test "a record type the account gate does not serve is never shown" do
    assert_not AccountPolicy.new(Object.new, user: clients(:one)).show?
  end

  test "a record type the organization gate does not serve is never shown" do
    assert_not OrganizationPolicy.new(Object.new, user: operators(:one)).show?
  end

  # Enforcement cases are staff-only across the board; a client holding one is
  # not a reason to read or raise them.
  test "enforcement cases are refused to anyone who is not an operator" do
    as_client = EnforcementCasePolicy.new(Object.new, user: clients(:one))

    assert_not as_client.index?
    assert_not as_client.show?
    assert_not as_client.create?

    as_operator = EnforcementCasePolicy.new(Object.new, user: operators(:one))

    assert_predicate as_operator, :index?
    assert_predicate as_operator, :show?
    assert_predicate as_operator, :create?
  end

  # A checkpoint may only be shown, and only completed, while the cycle is
  # actually waiting at one -- the two answer identically by design.
  test "the checkpoint gate follows the cycle's own status and nothing else" do
    ClientSignInFlowStatus.ensure_defaults!
    pending = ClientSignInFlow.new(status_id: ClientSignInFlow::STATUS_NAMES.key("CHECKPOINT_PENDING"))
    elsewhere = ClientSignInFlow.new(status_id: ClientSignInFlow::STATUS_NAMES.key("STARTED"))

    assert_predicate SignIn::CyclePolicy.new(pending, user: clients(:one)), :show_checkpoint?
    assert_predicate SignIn::CyclePolicy.new(pending, user: clients(:one)), :complete_checkpoint?
    assert_not SignIn::CyclePolicy.new(elsewhere, user: clients(:one)).show_checkpoint?
    assert_not SignIn::CyclePolicy.new(Object.new, user: clients(:one)).show_checkpoint?
  end

  # A return target whose query string cannot even be parsed is treated as
  # dangerous rather than safe: an unparsable query is exactly what a smuggled
  # redirect parameter looks like.
  test "a return target with an unparsable query is treated as dangerous" do
    resolver = RedirectsPathTargetResolver.new("/settings", source: :test)

    assert_not resolver.send(:dangerous_query_key?, nil)
    assert_not resolver.send(:dangerous_query_key?, "ok=1")
    assert resolver.send(:dangerous_query_key?, "return_to=%2Fevil")
    assert resolver.send(:dangerous_query_key?, "a[]=1&a[b]=2")
  end

  test "a session-limit token reference that was not signed here resolves to no token" do
    assert_nil SessionLimitResolutionTokenRef.find_client_token("not-a-signed-ref")
    assert_nil SessionLimitResolutionTokenRef.find_client_token(nil)
  end

  test "each surface's step-up replay store uses its own transaction table" do
    {
      "app" => ClientStepUpCeremonyTransaction,
      "com" => VisitorStepUpCeremonyTransaction,
      "org" => OperatorStepUpCeremonyTransaction,
    }.each do |surface, model|
      store = IdentityStepUpCeremonyReplayStore.for(surface)

      assert_equal model, store.send(:transaction_class)
      assert_not store.consumed?("never-issued-jti"), surface
    end

    assert_raises(IdentityStepUpCeremonyContract::Error) { IdentityStepUpCeremonyReplayStore.for("martian") }
  end
end
