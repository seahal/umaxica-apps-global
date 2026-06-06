# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Selector::BootstrapAuthorityTest < ActiveSupport::TestCase
  setup do
    ensure_reference_rows!
  end

  test "app bootstrap creates account organization membership and avatar idempotently" do
    user = create_client!

    assert_difference -> { ClientAccount.count }, 1 do
      assert_difference -> { ClientIdentity.count }, 1 do
        assert_difference -> { Persona.count }, 1 do
          assert_difference -> { Enterprise.count }, 1 do
            assert_difference -> { Avatar.count }, 1 do
              Acme::Selector::BootstrapAuthority.call(surface: :app, principal: user)
            end
          end
        end
      end
    end

    assert_no_difference -> { ClientAccount.count + Persona.count + Enterprise.count + Avatar.count } do
      Acme::Selector::BootstrapAuthority.call(surface: :app, principal: user)
    end
    assert_equal 1, Persona.first.current_memberships.count
  end

  test "com and org bootstrap do not create app avatars" do
    visitor = create_visitor!
    operator = create_operator!

    assert_no_difference -> { Avatar.count } do
      Acme::Selector::BootstrapAuthority.call(surface: :com, principal: visitor)
      Acme::Selector::BootstrapAuthority.call(surface: :org, principal: operator)
    end

    assert_equal 1, VisitorAccount.where(visitor_id: visitor.id).count
    assert_equal 1, OperatorAccount.where(staff_id: operator.id).count
    assert_equal 1, Individual.count
    assert_equal 1, Agent.count
  end

  private

  def ensure_reference_rows!
    [
      ClientStatus, ClientVisibility, ClientMfaLevel, ClientMfaStatus,
      VisitorStatus, VisitorVisibility, VisitorMfaLevel, VisitorMfaStatus,
      OperatorStatus, OperatorVisibility, OperatorMfaLevel, OperatorMfaStatus,
      ClientIdentityState, VisitorIdentityState, OperatorIdentityState,
      PersonaMembershipKind, PersonaMembershipState,
      IndividualMembershipKind, IndividualMembershipState,
      AgentMembershipKind, AgentMembershipState,
      HandleStatus,
    ].each { |klass| klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!) }
    AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
  end

  def create_client!
    Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  def create_visitor!
    Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
  end

  def create_operator!
    Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
  end
end
