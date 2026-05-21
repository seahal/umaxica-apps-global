# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_banners
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  ends_at    :datetime         default(9999-12-31 23:59:59.000000000 UTC +00:00), not null
#  published  :boolean          default(FALSE), not null
#  starts_at  :datetime         not null
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_client_banners_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#
require "test_helper"

class ClientBannerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :client_banners, :clients, :client_statuses

  test "user is required" do
    banner = ClientBanner.new(body: "Banner body")

    assert_not banner.valid?
    assert_includes banner.errors[:user], "を入力してください"
  end

  test "body is required" do
    banner = ClientBanner.new(user: clients(:reserved_user), body: "")

    assert_not banner.valid?
    assert_includes banner.errors[:body], "を入力してください"
  end

  test "published scope returns published banners only" do
    assert_includes ClientBanner.published, client_banners(:current_user_banner)
    assert_not_includes ClientBanner.published, client_banners(:unpublished_user_banner)
  end

  test "active_now scope returns currently active banners only" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      assert_includes ClientBanner.active_now, client_banners(:current_user_banner)
      assert_not_includes ClientBanner.active_now, client_banners(:future_user_banner)
      assert_not_includes ClientBanner.active_now, client_banners(:expired_user_banner)
    end
  end

  test "active_now includes starts_at boundary and excludes ends_at boundary" do
    now = Time.zone.parse("2026-03-18 00:00:00 UTC")
    starts_now = ClientBanner.create!(
      user: clients(:reserved_user),
      body: "Starts now",
      published: true,
      starts_at: now,
      ends_at: now + 1.hour,
    )
    ends_now = ClientBanner.create!(
      user: clients(:reserved_user),
      body: "Ends now",
      published: true,
      starts_at: now - 1.hour,
      ends_at: now,
    )

    travel_to now do
      assert_includes ClientBanner.active_now, starts_now
      assert_not_includes ClientBanner.active_now, ends_now
    end
  end

  test "current scope returns published active banners ordered by starts_at desc then id desc" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      operation = -> { [client_banners(:newer_current_user_banner).id, client_banners(:current_user_banner).id] }
      expected_ids = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call

      assert_equal expected_ids, ClientBanner.current.pluck(:id)
    end
  end

  test "actor returns user" do
    assert_equal clients(:reserved_user), client_banners(:current_user_banner).actor
  end

  test "reserved user can own banner" do
    assert_predicate client_banners(:current_user_banner), :valid?
  end

  test "ends_at must be after starts_at" do
    banner = ClientBanner.new(
      user: clients(:reserved_user),
      body: "Banner body",
      starts_at: Time.zone.parse("2026-03-18 12:00:00 UTC"),
      ends_at: Time.zone.parse("2026-03-18 12:00:00 UTC"),
    )

    assert_not banner.valid?
    assert_not_empty banner.errors[:ends_at]
  end
end
