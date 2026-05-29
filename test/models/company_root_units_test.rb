# typed: false
# frozen_string_literal: true

require "test_helper"

class CompanyRootUnitsTest < ActiveSupport::TestCase
  test "root_units returns only units without parent" do
    company = Company.create!(name: "Acme")
    root = CompanyUnit.create!(company:, name: "Root")
    _child = CompanyUnit.create!(company:, parent: root, name: "Child")

    assert_includes company.root_units, root
    assert_not_includes company.root_units, _child
  end

  test "root_units returns multiple root units" do
    company = Company.create!(name: "Acme")
    root_a = CompanyUnit.create!(company:, name: "Root A")
    root_b = CompanyUnit.create!(company:, name: "Root B")

    assert_equal 2, company.root_units.count
    assert_includes company.root_units, root_a
    assert_includes company.root_units, root_b
  end

  test "root_units returns empty when no units exist" do
    company = Company.create!(name: "Empty")

    assert_empty company.root_units
  end
end
