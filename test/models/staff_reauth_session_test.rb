# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_reauth_sessions
# Database name: token
#
#  id             :bigint           not null, primary key
#  attempt_count  :integer          default(0), not null
#  lapses_at      :datetime         default(Infinity), not null
#  method         :string
#  purge_at       :datetime         default(Infinity), not null
#  return_to      :text             not null
#  scope          :string           not null
#  status         :string           not null
#  verified_at    :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  staff_token_id :bigint           not null
#
# Indexes
#
#  index_staff_reauth_sessions_on_staff_token_id  (staff_token_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_token_id => staff_tokens.id) ON DELETE => cascade
#
require "test_helper"

class OperatorReauthSessionTest < ActiveSupport::TestCase
  setup do
    @staff = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH)
    @staff_token = OperatorToken.create!(staff: @staff)
    @valid_params = {
      staff_token: @staff_token,
      scope: "account_update",
      return_to: "/account",
      method: "passkey",
      status: "PENDING",
      lapses_at: 10.minutes.from_now,
    }.freeze
  end

  test "is valid with nil method" do
    assert_predicate OperatorReauthSession.new(@valid_params.merge(method: nil)), :valid?
  end

  test "is valid with known methods" do
    OperatorReauthSession::METHODS.each do |method|
      assert_predicate OperatorReauthSession.new(@valid_params.merge(method: method)), :valid?, method
    end
  end

  test "is invalid with unknown method" do
    session = OperatorReauthSession.new(@valid_params.merge(method: "sms"))

    assert_not session.valid?
    assert_not_empty session.errors[:method]
  end

  test "is valid with pending and verified statuses" do
    OperatorReauthSession::STATUSES.each do |status|
      assert_predicate OperatorReauthSession.new(@valid_params.merge(status: status)), :valid?, status
    end
  end

  test "is invalid with removed or unknown statuses" do
    %w(CANCELLED EXPIRED UNKNOWN).each do |status|
      session = OperatorReauthSession.new(@valid_params.merge(status: status))

      assert_not session.valid?, status
      assert_not_empty session.errors[:status]
    end
  end

  test "belongs to token" do
    session = OperatorReauthSession.create!(@valid_params)

    assert_equal @staff_token, session.staff_token
  end

  test "duplicate token row raises record not unique" do
    OperatorReauthSession.create!(@valid_params)

    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorReauthSession.create!(@valid_params.merge(method: "email_otp", status: "VERIFIED"))
    end
  end

  test "expired? reflects lapses_at boundary" do
    assert_predicate OperatorReauthSession.new(@valid_params.merge(lapses_at: Time.current)), :expired?
    assert_not OperatorReauthSession.new(@valid_params.merge(lapses_at: 1.second.from_now)).expired?
  end

  test "scopes filter and order sessions" do
    older_staff = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH)
    newer_staff = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH)
    older_token = OperatorToken.create!(staff: older_staff)
    newer_token = OperatorToken.create!(staff: newer_staff)
    older = OperatorReauthSession.create!(
      @valid_params.merge(
        staff_token: older_token, return_to: "/older", created_at: 2.minutes.ago,
        updated_at: 2.minutes.ago,
      ),
    )
    OperatorReauthSession.create!(
      @valid_params.merge(staff_token: @staff_token, return_to: "/verified", status: "VERIFIED"),
    )
    newer = OperatorReauthSession.create!(
      @valid_params.merge(
        staff_token: newer_token, return_to: "/newer", created_at: 1.minute.ago,
        updated_at: 1.minute.ago,
      ),
    )

    assert_equal [newer, older], OperatorReauthSession.pending.recent_first.to_a
  end

  test "same actor can have independent token-bound tickets" do
    other_token = OperatorToken.create!(staff: @staff)
    first = OperatorReauthSession.create!(@valid_params)
    second = OperatorReauthSession.create!(@valid_params.merge(staff_token: other_token, return_to: "/other"))

    assert_equal [first, second].sort,
                 OperatorReauthSession.where(staff_token_id: [@staff_token.id, other_token.id]).to_a.sort
  end
end
