# typed: false
# frozen_string_literal: true

require "test_helper"

class EnterpriseRootUnitsTest < ActiveSupport::TestCase
  test "root_units returns only units without parent" do
    enterprise = Enterprise.create!(name: "Acme")
    root = EnterpriseUnit.create!(enterprise:, name: "Root")
    _child = EnterpriseUnit.create!(enterprise:, parent: root, name: "Child")

    assert_includes enterprise.root_units, root
    assert_not_includes enterprise.root_units, _child
  end

  test "root_units returns multiple root units" do
    enterprise = Enterprise.create!(name: "Acme")
    root_a = EnterpriseUnit.create!(enterprise:, name: "Root A")
    root_b = EnterpriseUnit.create!(enterprise:, name: "Root B")

    assert_equal 2, enterprise.root_units.count
    assert_includes enterprise.root_units, root_a
    assert_includes enterprise.root_units, root_b
  end

  test "root_units returns empty when no units exist" do
    enterprise = Enterprise.create!(name: "Empty")

    assert_empty enterprise.root_units
  end
end
