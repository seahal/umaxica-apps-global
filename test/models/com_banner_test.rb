# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_banners
# Database name: guest
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  ends_at    :datetime         default(9999-12-31 23:59:59.000000000 UTC +00:00), not null
#  published  :boolean          default(FALSE), not null
#  starts_at  :datetime         not null
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class ComBannerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :com_banners

  test "inherits from guest record" do
    assert_operator ComBanner, :<, GuestRecord
  end

  test "actor is not required" do
    banner = ComBanner.new(body: "Banner body")

    assert_predicate banner, :valid?
  end

  test "actor returns nil" do
    assert_nil com_banners(:current_com_banner).actor
  end

  test "default values are applied" do
    banner = ComBanner.create!(body: "Default banner body").reload

    assert_not banner.published
    assert_not_nil banner.starts_at
    assert_equal 9999, banner.ends_at.year
    assert_equal "", banner.title
  end

  test "current scope orders same starts_at by id desc" do
    starts_at = Time.zone.parse("2026-03-18 00:00:00 UTC")
    older = ComBanner.create!(body: "Older", published: true, starts_at: starts_at, ends_at: starts_at + 1.day)
    newer = ComBanner.create!(body: "Newer", published: true, starts_at: starts_at, ends_at: starts_at + 1.day)

    travel_to starts_at + 1.hour do
      assert_equal [newer, older], ComBanner.where(id: [older.id, newer.id]).current.to_a
    end
  end

  test "database columns keep expected defaults and null constraints" do
    published_column = ComBanner.columns_hash["published"]
    title_column = ComBanner.columns_hash["title"]
    body_column = ComBanner.columns_hash["body"]
    starts_at_column = ComBanner.columns_hash["starts_at"]
    ends_at_column = ComBanner.columns_hash["ends_at"]

    assert_not published_column.default
    assert_equal "", title_column.default
    assert_not body_column.null
    assert_not starts_at_column.null
    assert_not ends_at_column.null
  end

  test "database rejects null body when validations are bypassed" do
    banner = ComBanner.new(body: nil)

    assert_raises(ActiveRecord::NotNullViolation) do
      ActiveRecord::Base.logger.silence { banner.save!(validate: false) }
    end
  end

  test "database check constraint rejects ends_at equal to starts_at when validations are bypassed" do
    banner = ComBanner.new(
      body: "Invalid window",
      starts_at: Time.zone.parse("2026-03-18 00:00:00 UTC"),
      ends_at: Time.zone.parse("2026-03-18 00:00:00 UTC"),
    )
    exception_classes = [ActiveRecord::StatementInvalid]
    exception_classes << ActiveRecord::CheckConstraintViolation if defined?(ActiveRecord::CheckConstraintViolation)

    assert_raises(*exception_classes) do
      ActiveRecord::Base.logger.silence { banner.save!(validate: false) }
    end
  end
end
