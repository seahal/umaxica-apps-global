# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: divisions
# Database name: org_principal
#
#  id                 :bigint           not null, primary key
#  name               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  division_status_id :bigint           default(0), not null
#  organization_id    :bigint           not null
#
# Indexes
#
#  index_divisions_on_division_status_id_and_organization_id  (division_status_id,organization_id) UNIQUE
#  index_divisions_on_organization_id                         (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (division_status_id => division_statuses.id)
#  fk_rails_...  (organization_id => organizations.id)
#

require "test_helper"

class DivisionTest < ActiveSupport::TestCase
  fixtures :division_statuses, :organization_statuses, :organizations, :divisions

  test "class is defined" do
    assert_equal "Division", Division.name
  end

  test "fixture is valid" do
    assert_predicate divisions(:one), :valid?
  end

  test "organization is required" do
    division = Division.new(name: "Missing Organization", division_status: division_statuses(:nothing))

    assert_not_predicate division, :valid?
    assert_not_empty division.errors[:organization]
  end

  test "organization with divisions cannot be destroyed" do
    organization = organizations(:one)

    assert_not organization.destroy
    assert_not_empty organization.errors[:base]
  end
end
