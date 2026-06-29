# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class ClientSecretCredentialPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = ClientSecretCredentialPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
  end

  def test_show
    assert_not @policy.show?
  end

  def test_create
    assert_not @policy.create?
  end

  def test_new
    assert_not @policy.new?
  end

  def test_update
    assert_not @policy.update?
  end

  def test_edit
    assert_not @policy.edit?
  end

  def test_destroy
    assert_not @policy.destroy?
  end

  # index?/new?/create? allow any client actor (registration has no persisted record yet).
  def test_index_and_create_allow_client
    policy = ClientSecretCredentialPolicy.new(ClientSecretCredential.new, user: Client.new(id: 1))

    assert_predicate policy, :index?
    assert_predicate policy, :create?
    assert_predicate policy, :new?
  end

  def test_index_and_create_deny_other_actor_types
    policy = ClientSecretCredentialPolicy.new(ClientSecretCredential.new, user: Operator.new(id: 1))

    assert_not policy.index?
    assert_not policy.create?
  end

  # Per-record actions require ownership (record.user_id == user.id).
  def test_owner_may_manage_own_record
    owner = Client.new(id: 1)
    record = ClientSecretCredential.new(user_id: owner.id)
    policy = ClientSecretCredentialPolicy.new(record, user: owner)

    assert_predicate policy, :show?
    assert_predicate policy, :update?
    assert_predicate policy, :edit?
    assert_predicate policy, :destroy?
    assert_predicate policy, :regenerate?
  end

  def test_non_owner_may_not_manage_record
    record = ClientSecretCredential.new(user_id: 1)
    policy = ClientSecretCredentialPolicy.new(record, user: Client.new(id: 2))

    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
    assert_not policy.regenerate?
  end
end
