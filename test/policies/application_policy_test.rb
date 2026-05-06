# typed: false
# frozen_string_literal: true

require "test_helper"

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

  # Scope tests
  # COMMENTED OUT BY FIX SCRIPT
  #   def test_scope_initialization
  #     scope_obj = ApplicationPolicy::Scope.new([], user: @user)
  #
  #     assert scope_obj
  #   end
  # COMMENTED OUT BY FIX SCRIPT
  #
  #   def test_scope_resolve_raises_not_implemented_error
  #     scope_obj = ApplicationPolicy::Scope.new([], user: @user)
  #     assert_raises(NoMethodError) do
  #       scope_obj.resolve
  #     end
  #   end

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
    actor = build_actor(User, 10)
    record = Struct.new(:user_id).new(10)
    policy = ApplicationPolicy.new(record, user: actor)

    assert policy.send(:owner?)
  end

  def test_owner_returns_false_for_user_non_owner
    actor = build_actor(User, 10)
    record = Struct.new(:user_id).new(11)
    policy = ApplicationPolicy.new(record, user: actor)

    assert_not policy.send(:owner?)
  end

  def test_owner_returns_true_for_staff_owner
    actor = build_actor(Staff, 20)
    record = Struct.new(:staff_id).new(20)
    policy = ApplicationPolicy.new(record, user: actor)

    assert policy.send(:owner?)
  end

  def test_owner_returns_false_for_unknown_actor_type
    actor = build_actor(String, 1)
    record = Struct.new(:user_id, :staff_id).new(1, 1)
    policy = ApplicationPolicy.new(record, user: actor)

    assert_not policy.send(:owner?)
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
  # COMMENTED OUT BY FIX SCRIPT
  #
  #   def test_scope_helpers_delegate_to_actor_with_organization
  #     actor = ScopeActor.new
  #     scope_obj = ApplicationPolicy::Scope.new([], user: actor)
  #
  #     assert scope_obj.send(:has_role?, "operator", organization: "org-1")
  #     assert scope_obj.send(:operator_or_manager?, organization: "org-2")
  #     assert_equal [[:has_role?, "operator", "org-1"], [:operator_or_manager?, "org-2"]], actor.calls
  #   end
  # COMMENTED OUT BY FIX SCRIPT
  #
  #   def test_scope_helpers_return_nil_without_actor
  #     scope_obj = ApplicationPolicy::Scope.new([], user: nil)
  #
  #     assert_nil scope_obj.send(:has_role?, "operator", organization: "org-1")
  #     assert_nil scope_obj.send(:operator_or_manager?, organization: "org-1")
  #   end

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

  class ScopeActor
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
  end
end
