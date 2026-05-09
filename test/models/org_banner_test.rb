# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_banners
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
require "test_helper"

class OrgBannerTest < ActiveSupport::TestCase
  fixtures :org_banners, :staffs, :staff_statuses

  test "staff is required" do
    banner = OrgBanner.new(body: "Banner body")

    assert_not banner.valid?
    assert_includes banner.errors[:staff], "を入力してください"
  end

  test "actor returns staff" do
    assert_equal staffs(:reserved_staff), org_banners(:current_org_banner).actor
  end

  test "reserved staff can own banner" do
    assert_predicate org_banners(:current_org_banner), :valid?
  end
end
