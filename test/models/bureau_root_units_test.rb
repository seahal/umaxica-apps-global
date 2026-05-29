# typed: false
# frozen_string_literal: true

require "test_helper"

class BureauRootUnitsTest < ActiveSupport::TestCase
  test "root_units returns only units without parent" do
    bureau = Bureau.create!(name: "Division")
    root = BureauUnit.create!(bureau:, name: "Root")
    _child = BureauUnit.create!(bureau:, parent: root, name: "Child")

    assert_includes bureau.root_units, root
    assert_not_includes bureau.root_units, _child
  end

  test "root_units returns multiple root units" do
    bureau = Bureau.create!(name: "Division")
    root_a = BureauUnit.create!(bureau:, name: "Root A")
    root_b = BureauUnit.create!(bureau:, name: "Root B")

    assert_equal 2, bureau.root_units.count
    assert_includes bureau.root_units, root_a
    assert_includes bureau.root_units, root_b
  end

  test "root_units returns empty when no units exist" do
    bureau = Bureau.create!(name: "Empty")

    assert_empty bureau.root_units
  end
end
