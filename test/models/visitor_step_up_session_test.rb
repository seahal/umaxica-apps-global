# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_step_up_sessions
# Database name: com_ticket
#
#  id               :bigint           not null, primary key
#  attempt_count    :integer          default(0), not null
#  discarded_at     :datetime         default(Infinity), not null
#  method           :string
#  purged_at        :datetime         default(Infinity), not null
#  return_to        :text             not null
#  scope            :string           not null
#  status           :string           not null
#  verified_at      :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  visitor_token_id :bigint           not null
#
# Indexes
#
#  index_visitor_step_up_sessions_on_visitor_token_id  (visitor_token_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (visitor_token_id => visitor_tokens.id) ON DELETE => cascade
#
require "test_helper"

class VisitorStepUpSessionTest < ActiveSupport::TestCase
  setup do
    ensure_visitor_reference_records!
    ensure_visitor_token_reference_records!
    @visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::BOTH,
    )
    @visitor_token = VisitorToken.create!(visitor: @visitor)
    @valid_params = {
      visitor_token: @visitor_token,
      scope: "account_update",
      return_to: "/account",
      method: "passkey",
      status: "PENDING",
      discarded_at: 10.minutes.from_now,
    }.freeze
  end

  test "is valid with nil method" do
    assert_predicate VisitorStepUpSession.new(@valid_params.merge(method: nil)), :valid?
  end

  test "is valid with known methods" do
    VisitorStepUpSession::METHODS.each do |method|
      assert_predicate VisitorStepUpSession.new(@valid_params.merge(method: method)), :valid?, method
    end
  end

  test "is invalid with unknown method" do
    session = VisitorStepUpSession.new(@valid_params.merge(method: "sms"))

    assert_not session.valid?
    assert_not_empty session.errors[:method]
  end

  test "is valid with pending and verified statuses" do
    VisitorStepUpSession::STATUSES.each do |status|
      assert_predicate VisitorStepUpSession.new(@valid_params.merge(status: status)), :valid?, status
    end
  end

  test "is invalid with removed or unknown statuses" do
    %w(CANCELLED EXPIRED UNKNOWN).each do |status|
      session = VisitorStepUpSession.new(@valid_params.merge(status: status))

      assert_not session.valid?, status
      assert_not_empty session.errors[:status]
    end
  end

  test "belongs to token" do
    session = VisitorStepUpSession.create!(@valid_params)

    assert_equal @visitor_token, session.visitor_token
  end

  test "duplicate token row raises record not unique" do
    VisitorStepUpSession.create!(@valid_params)

    assert_raises(ActiveRecord::RecordNotUnique) do
      VisitorStepUpSession.create!(@valid_params.merge(method: "email_otp", status: "VERIFIED"))
    end
  end

  test "expired? reflects discarded_at boundary" do
    assert_predicate VisitorStepUpSession.new(@valid_params.merge(discarded_at: Time.current)), :expired?
    assert_not VisitorStepUpSession.new(@valid_params.merge(discarded_at: 1.second.from_now)).expired?
  end

  test "pending scope returns only pending sessions" do
    other_token = VisitorToken.create!(visitor: @visitor)
    pending = VisitorStepUpSession.create!(@valid_params)
    VisitorStepUpSession.create!(
      @valid_params.merge(visitor_token: other_token, status: "VERIFIED", return_to: "/verified"),
    )

    assert_equal [pending], VisitorStepUpSession.pending.to_a
  end

  test "same actor can have independent token-bound tickets" do
    other_token = VisitorToken.create!(visitor: @visitor)
    first = VisitorStepUpSession.create!(@valid_params)
    second = VisitorStepUpSession.create!(@valid_params.merge(visitor_token: other_token, return_to: "/other"))

    assert_equal [first, second].sort,
                 VisitorStepUpSession.where(visitor_token_id: [@visitor_token.id, other_token.id]).to_a.sort
  end
end
