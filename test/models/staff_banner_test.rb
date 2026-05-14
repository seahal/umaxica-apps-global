# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_banners
# Database name: operator
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
#  index_staff_banners_on_staff_id  (staff_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#
require "test_helper"

class OperatorBannerTest < ActiveSupport::TestCase
  fixtures :staff_banners, :staffs, :staff_statuses

  test "staff is required" do
    banner = OperatorBanner.new(body: "Banner body")

    assert_not banner.valid?
    assert_includes banner.errors[:staff], "を入力してください"
  end

  test "actor returns staff" do
    assert_equal staffs(:reserved_staff).id, staff_banners(:current_staff_banner).actor.id
  end

  test "reserved staff can own banner" do
    assert_predicate staff_banners(:current_staff_banner), :valid?
  end
end
