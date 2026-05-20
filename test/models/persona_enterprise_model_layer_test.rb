# typed: false
# frozen_string_literal: true

require "test_helper"

class PersonaEnterpriseModelLayerTest < ActiveSupport::TestCase
  setup do
    ClientIdentityState.ensure_defaults!
    PersonaMembershipKind.ensure_defaults!
    PersonaMembershipState.ensure_defaults!
    PersonaMembershipRevokeReason.ensure_defaults!
  end

  test "account and collective concerns are included" do
    assert_includes Persona.included_modules, Account
    assert_includes Enterprise.included_modules, Collective
  end

  test "root unit creates self closure row" do
    enterprise = Enterprise.create!(name: "Acme")
    root = EnterpriseUnit.create!(enterprise:, name: "Root")

    closure = EnterpriseUnitClosure.find_by!(ancestor: root, descendant: root)

    assert_equal 0, closure.depth
    assert_predicate root, :root?
    assert_predicate root, :leaf?
    assert_equal [root], root.subtree.to_a
  end

  test "child unit creates ancestor closure rows" do
    enterprise = Enterprise.create!(name: "Acme")
    root = EnterpriseUnit.create!(enterprise:, name: "Root")
    child = EnterpriseUnit.create!(enterprise:, parent: root, name: "Child")

    assert_equal 0, EnterpriseUnitClosure.find_by!(ancestor: child, descendant: child).depth
    assert_equal 1, EnterpriseUnitClosure.find_by!(ancestor: root, descendant: child).depth
    assert_equal [root], child.ancestors.to_a
    assert_equal [child], root.descendants.to_a
    assert_not root.leaf?
  end

  test "unit parent must belong to the same enterprise" do
    first = Enterprise.create!(name: "First")
    second = Enterprise.create!(name: "Second")
    parent = EnterpriseUnit.create!(enterprise: first, name: "Root")
    child = EnterpriseUnit.new(enterprise: second, parent:, name: "Invalid")

    assert_not child.valid?
    assert child.errors.of_kind?(:parent, :invalid)
  end

  test "unit parent cannot be changed after create" do
    enterprise = Enterprise.create!(name: "Acme")
    first = EnterpriseUnit.create!(enterprise:, name: "First")
    second = EnterpriseUnit.create!(enterprise:, name: "Second")

    second.parent = first

    assert_not second.valid?
    assert second.errors.of_kind?(:parent_id, :invalid)
  end

  test "membership validates unit enterprise" do
    persona = Persona.create!(client_identity: client_identity("persona-membership-mismatch"))
    enterprise = Enterprise.create!(name: "Acme")
    other = Enterprise.create!(name: "Other")
    other_unit = EnterpriseUnit.create!(enterprise: other, name: "Other Root")
    membership = PersonaMembership.new(
      persona:,
      enterprise:,
      enterprise_unit: other_unit,
      membership_kind_id: PersonaMembershipKind::OWNER,
      membership_state_id: PersonaMembershipState::ACTIVE,
    )

    assert_not membership.valid?
    assert membership.errors.of_kind?(:enterprise_unit, :invalid)
  end

  test "allows only one active primary membership per persona" do
    persona = Persona.create!(client_identity: client_identity("persona-primary"))
    enterprise = Enterprise.create!(name: "Acme")
    unit = EnterpriseUnit.create!(enterprise:, name: "Root")
    attrs = {
      persona:,
      enterprise:,
      enterprise_unit: unit,
      membership_kind_id: PersonaMembershipKind::OWNER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: true,
    }
    PersonaMembership.create!(attrs)

    duplicate = PersonaMembership.new(attrs)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:primary, :taken)
  end

  test "database rejects a second persona for the same client identity" do
    identity = client_identity("persona-identity-unique")
    Persona.create!(client_identity: identity)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Persona.transaction(requires_new: true) do
        Persona.insert_all!(
          [
            {
              client_identity_id: identity.id,
              public_id: "dup-#{SecureRandom.hex(8)}",
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end
  end

  test "database rejects unit parent from a different enterprise" do
    first = Enterprise.create!(name: "First")
    second = Enterprise.create!(name: "Second")
    parent = EnterpriseUnit.create!(enterprise: first, name: "Root")

    assert_raises(ActiveRecord::InvalidForeignKey) do
      EnterpriseUnit.transaction(requires_new: true) do
        EnterpriseUnit.insert_all!(
          [
            {
              enterprise_id: second.id,
              parent_id: parent.id,
              public_id: "unit-#{SecureRandom.hex(8)}",
              name: "Invalid",
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end
  end

  test "database rejects membership whose unit belongs to another enterprise" do
    persona = Persona.create!(client_identity: client_identity("persona-db-membership-mismatch"))
    enterprise = Enterprise.create!(name: "Acme")
    other = Enterprise.create!(name: "Other")
    other_unit = EnterpriseUnit.create!(enterprise: other, name: "Other Root")

    assert_raises(ActiveRecord::InvalidForeignKey) do
      PersonaMembership.transaction(requires_new: true) do
        PersonaMembership.insert_all!(
          [
            {
              persona_id: persona.id,
              enterprise_id: enterprise.id,
              enterprise_unit_id: other_unit.id,
              membership_kind_id: PersonaMembershipKind::OWNER,
              membership_state_id: PersonaMembershipState::ACTIVE,
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end
  end

  test "database rejects non-self closure rows with depth zero" do
    enterprise = Enterprise.create!(name: "Acme")
    root = EnterpriseUnit.create!(enterprise:, name: "Root")
    child = EnterpriseUnit.create!(enterprise:, parent: root, name: "Child")

    assert_raises(ActiveRecord::StatementInvalid) do
      EnterpriseUnitClosure.transaction(requires_new: true) do
        EnterpriseUnitClosure.insert_all!(
          [
            {
              ancestor_id: root.id,
              descendant_id: child.id,
              depth: 0,
              created_at: Time.current,
              updated_at: Time.current,
            },
          ],
        )
      end
    end
  end

  private

  def client_identity(label)
    ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: label,
      audience: "apex_app",
      source_record_id: Zlib.crc32(label),
      status_id: ClientIdentityState::ACTIVE,
    )
  end
end
