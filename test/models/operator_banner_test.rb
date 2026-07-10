# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_banners
# Database name: org_principal
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  ends_at    :datetime         default(9999-12-31 23:59:59.000000000 UTC +00:00), not null
#  published  :boolean          default(FALSE), not null
#  starts_at  :datetime         not null
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_operator_banners_on_staff_id  (staff_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#
require "test_helper"

class OperatorBannerTest < ActiveSupport::TestCase
  fixtures :operator_banners, :operators, :operator_statuses

  test "staff is required" do
    banner = OperatorBanner.new(body: "Banner body")

    assert_not banner.valid?
    assert_not_empty banner.errors[:staff]
  end

  test "actor returns staff" do
    assert_equal operators(:reserved_staff).id, operator_banners(:current_staff_banner).actor.id
  end

  test "reserved staff can own banner" do
    assert_predicate operator_banners(:current_staff_banner), :valid?
  end
end
