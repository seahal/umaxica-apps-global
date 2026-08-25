# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationPolicyTest < ActiveSupport::TestCase
  class TestRecord
    attr_reader :marker

    def initialize
      @marker = :test_record
    end
  end

  class RecordWithOrganization
    attr_reader :organization

    def initialize(organization)
      @organization = organization
    end
  end

  class RecordWithOrganizationId
    attr_reader :organization_id

    def initialize(organization_id)
      @organization_id = organization_id
    end
  end

  class RelationDouble
    attr_reader :none_called

    def none
      @none_called = true
      :none_scope
    end
  end

  class TestPolicy < ApplicationPolicy; end

  def setup
    @user = nil
    @record = TestRecord.new
    @policy = TestPolicy.new(@record, user: @user)
  end

  # Default behavior tests
  def test_index_returns_false_by_default
    assert_not @policy.send(:index?)
  end

  def test_show_returns_false_by_default
    assert_not @policy.send(:show?)
  end

  def test_create_returns_false_by_default
    assert_not @policy.send(:create?)
  end

  def test_new_delegates_to_create
    assert_equal @policy.send(:create?), @policy.send(:new?)
  end

  def test_update_returns_false_by_default
    assert_not @policy.send(:update?)
  end

  def test_edit_delegates_to_update
    assert_equal @policy.send(:update?), @policy.send(:edit?)
  end

  def test_destroy_returns_false_by_default
    assert_not @policy.send(:destroy?)
  end

  def test_relation_scope_denies_all_by_default
    relation = RelationDouble.new

    assert_equal :none_scope, @policy.apply_scope(relation, type: :active_record_relation)
    assert relation.none_called
  end

  # Attributes tests
  def test_user_attribute_is_accessible
    policy = ApplicationPolicy.new(@record, user: @user)

    assert_nil policy.user
  end

  def test_record_attribute_is_accessible
    policy = ApplicationPolicy.new(@record, user: @user)

    assert_equal @record, policy.record
  end

  def test_organization_uses_record_organization_when_available
    org = Object.new
    policy = ApplicationPolicy.new(RecordWithOrganization.new(org), user: nil)

    assert_equal org, policy.send(:organization)
  end

  def test_organization_uses_record_organization_id_when_organization_method_is_missing
    policy = ApplicationPolicy.new(RecordWithOrganizationId.new("org-1"), user: nil)

    assert_equal "org-1", policy.send(:organization)
  end

  def test_organization_returns_nil_when_record_has_no_organization_methods
    policy = ApplicationPolicy.new(TestRecord.new, user: nil)

    assert_nil policy.send(:organization)
  end

  def test_owner_returns_false_without_actor
    assert_not @policy.send(:owner?)
  end

  def test_owner_returns_true_for_user_owner
    actor = build_actor(Client, 10)
    record = Struct.new(:user_id).new(10)
    policy = ApplicationPolicy.new(record, user: actor)

    assert policy.send(:owner?)
  end

  def test_owner_returns_false_for_user_non_owner
    actor = build_actor(Client, 10)
    record = Struct.new(:user_id).new(11)
    policy = ApplicationPolicy.new(record, user: actor)

    assert_not policy.send(:owner?)
  end

  def test_owner_returns_true_for_staff_owner
    actor = build_actor(Operator, 20)
    record = Struct.new(:staff_id).new(20)
    policy = ApplicationPolicy.new(record, user: actor)

    assert policy.send(:owner?)
  end

  def test_owner_returns_true_for_visitor_owner
    actor = build_actor(Visitor, 30)
    record = Struct.new(:visitor_id).new(30)
    policy = ApplicationPolicy.new(record, user: actor)

    assert policy.send(:owner?)
  end

  def test_owner_returns_false_for_visitor_non_owner
    actor = build_actor(Visitor, 30)
    record = Struct.new(:visitor_id).new(31)
    policy = ApplicationPolicy.new(record, user: actor)

    assert_not policy.send(:owner?)
  end

  def test_owner_returns_false_for_unknown_actor_type
    actor = build_actor(String, 1)
    record = Struct.new(:client_id, :staff_id).new(1, 1)
    policy = ApplicationPolicy.new(record, user: actor)

    assert_not policy.send(:owner?)
  end

  def test_owner_returns_true_when_actor_and_record_are_same_user_record
    user = Client.new(id: 10)
    policy = ApplicationPolicy.new(user, user: user)

    assert policy.send(:owner?)
  end

  def test_role_helpers_pass_organization_to_actor
    org = Object.new
    actor = RoleActor.new
    policy = ApplicationPolicy.new(RecordWithOrganization.new(org), user: actor)

    assert policy.send(:operator?)
    assert policy.send(:manager?)
    assert policy.send(:editor?)
    assert policy.send(:contributor?)
    assert policy.send(:viewer?)
    assert policy.send(:operator_or_manager?)
    assert policy.send(:can_edit?)
    assert policy.send(:can_view?)
    assert policy.send(:can_contribute?)

    assert_equal(
      [
        [:has_role?, "operator", org],
        [:has_role?, "manager", org],
        [:has_role?, "editor", org],
        [:has_role?, "contributor", org],
        [:has_role?, "viewer", org],
        [:operator_or_manager?, org],
        [:can_edit?, org],
        [:can_view?, org],
        [:can_contribute?, org],
      ],
      actor.calls,
    )
  end

  def test_role_helpers_are_false_when_the_actor_is_missing
    policy = ApplicationPolicy.new(TestRecord.new, user: nil)

    assert_not policy.send(:operator?)
    assert_not policy.send(:manager?)
    assert_not policy.send(:editor?)
    assert_not policy.send(:contributor?)
    assert_not policy.send(:viewer?)
    assert_not policy.send(:operator_or_manager?)
    assert_not policy.send(:can_edit?)
    assert_not policy.send(:can_view?)
    assert_not policy.send(:can_contribute?)
  end

  private

  def build_actor(type_class, id)
    actor = Object.new
    actor.define_singleton_method(:id) { id }
    actor.define_singleton_method(:is_a?) do |klass|
      klass == type_class || super(klass)
    end
    actor
  end

  class RoleActor
    attr_reader :calls

    def initialize
      @calls = []
    end

    def has_role?(role_key, organization:)
      @calls << [:has_role?, role_key, organization]
      true
    end

    def operator_or_manager?(organization:)
      @calls << [:operator_or_manager?, organization]
      true
    end

    def can_edit?(organization:)
      @calls << [:can_edit?, organization]
      true
    end

    def can_view?(organization:)
      @calls << [:can_view?, organization]
      true
    end

    def can_contribute?(organization:)
      @calls << [:can_contribute?, organization]
      true
    end
  end
end
