# typed: false
# frozen_string_literal: true

require "test_helper"

# The session-limit manager holds a restricted token against a sign-in cycle, and
# every guard around it exists so the hold cannot be released by the wrong actor
# or against the wrong token. Each refusal below is a mismatch that would
# otherwise let one person's restricted session be cancelled from another's.
class SignInSessionLimitSurfaceBindingTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities, :client_token_kinds, :client_token_statuses,
           :operators, :operator_statuses

  def manager(cycle:, actor:, token: nil)
    SignInSessionLimitManager.new(cycle: cycle, actor: actor, token: token)
  end

  test "an actor from another surface is refused against the cycle's surface" do
    cycle = ClientSignInFlow.new
    subject = manager(cycle: cycle, actor: operators(:one))

    error =
      assert_raises(SignInSessionLimitManager::ActorMismatch) do
        subject.send(:ensure_actor_class!, SignInSessionLimitManager::SURFACES.fetch(ClientSignInFlow))
      end

    assert_match(/actor does not match sign-in cycle surface/, error.message)
  end

  test "an actor of the cycle's own surface passes the surface check" do
    subject = manager(cycle: ClientSignInFlow.new, actor: clients(:one))

    assert_nil subject.send(:ensure_actor_class!, SignInSessionLimitManager::SURFACES.fetch(ClientSignInFlow))
  end

  test "a cycle type with no surface entry is refused rather than defaulted" do
    subject = manager(cycle: ClientEmail.new, actor: clients(:one))

    assert_raises(SignInSessionLimitManager::InvalidCycle) { subject.send(:surface_metadata) }
  end

  # The bound token has to be the one presenting itself and has to still be
  # restricted; a token that has already been released is not a hold to cancel.
  test "a bound token that is no longer restricted is refused" do
    client = clients(:one)
    released = ClientToken.create!(
      user_id: client.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB, discarded_at: 1.day.from_now,
    )
    cycle = ClientSignInFlow.new(token_id: released.id)
    subject = manager(cycle: cycle, actor: client, token: released)

    error =
      assert_raises(SignInSessionLimitManager::TokenMismatch) do
        subject.send(:locked_restricted_token!, SignInSessionLimitManager::SURFACES.fetch(ClientSignInFlow))
      end

    assert_match(/sign-in cycle token is not restricted/, error.message)
  end

  test "a cycle bound to no token at all is refused before any lock is taken" do
    subject = manager(cycle: ClientSignInFlow.new, actor: clients(:one))

    assert_nil subject.send(:locked_bound_token, SignInSessionLimitManager::SURFACES.fetch(ClientSignInFlow))
    assert_raises(SignInSessionLimitManager::InvalidCycle) do
      subject.send(:locked_restricted_token!, SignInSessionLimitManager::SURFACES.fetch(ClientSignInFlow))
    end
  end

  # An unknown token class has no reference tables to seed, which is an empty
  # list rather than a raise: seeding is best-effort setup, not a guard.
  test "reference defaults are listed per token class and empty for an unknown one" do
    subject = manager(cycle: ClientSignInFlow.new, actor: clients(:one))

    assert_includes subject.send(:reference_models_for, ClientToken), ClientTokenStatus
    assert_includes subject.send(:reference_models_for, VisitorToken), VisitorTokenStatus
    assert_includes subject.send(:reference_models_for, OperatorToken), OperatorTokenStatus
    assert_empty subject.send(:reference_models_for, ClientEmail)
  end
end
