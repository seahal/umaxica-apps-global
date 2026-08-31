# typed: false
# frozen_string_literal: true

require "test_helper"

# Every credential list is scoped to the actor asking for it. A scope that
# returned another actor's rows would list one person's passkeys, recovery
# passcodes or TOTP credentials to another, so each one is pinned twice: it
# returns nothing at all without an actor, and only the actor's own rows with one.
class CredentialRelationScopeTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities, :operators, :operator_statuses

  CLIENT_SCOPED = {
    ClientPasskeyPolicy => [ClientPasskey, :user_id],
    ClientSecretCredentialPolicy => [ClientSecretCredential, :user_id],
    ClientTotpCredentialPolicy => [ClientTotpCredential, :user_id],
  }.freeze

  OTHER_SURFACE_SCOPED = {
    OperatorSecretCredentialPolicy => [OperatorSecretCredential, :staff_id],
    VisitorPasskeyPolicy => [VisitorPasskey, :visitor_id],
    VisitorSecretCredentialPolicy => [VisitorSecretCredential, :visitor_id],
  }.freeze

  def scoped(policy_class, relation, user:)
    policy_class.new(nil, user: user).apply_scope(relation, type: :active_record_relation)
  end

  (CLIENT_SCOPED.merge(OTHER_SURFACE_SCOPED)).each do |policy_class, (model, foreign_key)|
    test "#{policy_class} lists nothing at all without an actor" do
      assert_empty scoped(policy_class, model.all, user: nil).to_a
    end

    test "#{policy_class} scopes the list to the actor's own #{foreign_key}" do
      actor = Struct.new(:id).new(4_242)

      assert_includes scoped(policy_class, model.all, user: actor).to_sql, foreign_key.to_s
      assert_includes scoped(policy_class, model.all, user: actor).to_sql, "4242"
    end
  end

  # The avatar scope is narrower still: it is not merely "has an actor" but
  # "is a Client", because the other surfaces reach avatars through a different
  # assignment table entirely.
  test "the avatar scope lists nothing for an actor that is not a client" do
    assert_empty scoped(AvatarPolicy, Avatar.all, user: nil).to_a
    assert_empty scoped(AvatarPolicy, Avatar.all, user: operators(:one)).to_a
  end

  test "the avatar scope reaches a client's avatars through their own assignments" do
    sql = scoped(AvatarPolicy, Avatar.all, user: clients(:one)).to_sql

    assert_includes sql, "avatar_assignments"
    assert_includes sql, clients(:one).id.to_s
  end
end
