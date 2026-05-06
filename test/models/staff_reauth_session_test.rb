# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_reauth_sessions
# Database name: token
#
#  id            :bigint           not null, primary key
#  attempt_count :integer          default(0), not null
#  expires_at    :datetime         not null
#  method        :string           not null
#  return_to     :text             not null
#  scope         :string           not null
#  status        :string           not null
#  verified_at   :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  staff_id      :bigint           not null
#
# Indexes
#
#  index_staff_reauth_sessions_on_expires_at           (expires_at)
#  index_staff_reauth_sessions_on_staff_id_and_status  (staff_id,status)
#
require "test_helper"

class StaffReauthSessionTest < ActiveSupport::TestCase
  setup do
    @staff = Staff.create!(status_id: StaffStatus::ACTIVE, visibility_id: StaffVisibility::BOTH)
  end

  test "valid with required attributes" do
    session = StaffReauthSession.new(
      staff: @staff,
      scope: "account_update",
      return_to: "/account",
      method: "passkey",
      status: "PENDING",
      expires_at: 5.minutes.from_now,
    )

    assert_predicate session, :valid?, session.errors.full_messages.to_sentence
  end

  test "expired? reflects expires_at" do
    session = StaffReauthSession.new(
      staff: @staff,
      scope: "account_update",
      return_to: "/account",
      method: "passkey",
      status: "PENDING",
      expires_at: 1.second.ago,
    )

    assert_predicate session, :expired?
  end

  test "expired? is false before expires_at" do
    session = StaffReauthSession.new(expires_at: 1.second.from_now)

    assert_not session.expired?
  end

  test "validates enumerated method and status" do
    session = StaffReauthSession.new(
      staff: @staff,
      scope: "account_update",
      return_to: "/account",
      method: "sms",
      status: "UNKNOWN",
      expires_at: 5.minutes.from_now,
    )

    assert_not session.valid?
    assert_not_empty session.errors[:method]
    assert_not_empty session.errors[:status]
  end

  test "validates attempt count" do
    session = StaffReauthSession.new(
      staff: @staff,
      scope: "account_update",
      return_to: "/account",
      method: "totp",
      status: "PENDING",
      expires_at: 5.minutes.from_now,
      attempt_count: -1,
    )

    assert_not session.valid?
    assert_not_empty session.errors[:attempt_count]
  end

  test "scopes filter and order sessions" do
    older = StaffReauthSession.create!(
      staff: @staff,
      scope: "account_update",
      return_to: "/older",
      method: "passkey",
      status: "PENDING",
      expires_at: 5.minutes.from_now,
      created_at: 2.minutes.ago,
      updated_at: 2.minutes.ago,
    )
    StaffReauthSession.create!(
      staff: @staff,
      scope: "account_update",
      return_to: "/verified",
      method: "email_otp",
      status: "VERIFIED",
      expires_at: 5.minutes.from_now,
    )
    newer = StaffReauthSession.create!(
      staff: @staff,
      scope: "account_update",
      return_to: "/newer",
      method: "totp",
      status: "PENDING",
      expires_at: 5.minutes.from_now,
      created_at: 1.minute.ago,
      updated_at: 1.minute.ago,
    )

    assert_equal [newer, older], StaffReauthSession.for_staff(@staff).pending.recent_first.to_a
  end
end
