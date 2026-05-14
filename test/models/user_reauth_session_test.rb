# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_reauth_sessions
# Database name: mark
#
#  id            :bigint           not null, primary key
#  attempt_count :integer          default(0), not null
#  lapses_at     :datetime         default(Infinity), not null
#  method        :string
#  purge_at      :datetime         default(Infinity), not null
#  return_to     :text             not null
#  scope         :string           not null
#  status        :string           not null
#  verified_at   :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_token_id :bigint           not null
#
# Indexes
#
#  index_user_reauth_sessions_on_user_token_id  (user_token_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_token_id => user_tokens.id) ON DELETE => cascade
#
require "test_helper"

class UserReauthSessionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(status_id: UserStatus::ACTIVE, visibility_id: UserVisibility::BOTH)
    @user_token = UserToken.create!(user: @user)
    @valid_params = {
      user_token: @user_token,
      scope: "account_update",
      return_to: "/account",
      method: "passkey",
      status: "PENDING",
      lapses_at: 10.minutes.from_now,
    }.freeze
  end

  test "is valid with nil method" do
    assert_predicate UserReauthSession.new(@valid_params.merge(method: nil)), :valid?
  end

  test "is valid with known methods" do
    UserReauthSession::METHODS.each do |method|
      assert_predicate UserReauthSession.new(@valid_params.merge(method: method)), :valid?, method
    end
  end

  test "is invalid with unknown method" do
    session = UserReauthSession.new(@valid_params.merge(method: "sms"))

    assert_not session.valid?
    assert_not_empty session.errors[:method]
  end

  test "is valid with pending and verified statuses" do
    UserReauthSession::STATUSES.each do |status|
      assert_predicate UserReauthSession.new(@valid_params.merge(status: status)), :valid?, status
    end
  end

  test "is invalid with removed or unknown statuses" do
    %w(CANCELLED EXPIRED UNKNOWN).each do |status|
      session = UserReauthSession.new(@valid_params.merge(status: status))

      assert_not session.valid?, status
      assert_not_empty session.errors[:status]
    end
  end

  test "belongs to token" do
    session = UserReauthSession.create!(@valid_params)

    assert_equal @user_token, session.user_token
  end

  test "duplicate token row raises record not unique" do
    UserReauthSession.create!(@valid_params)

    assert_raises(ActiveRecord::RecordNotUnique) do
      UserReauthSession.create!(@valid_params.merge(method: "email_otp", status: "VERIFIED"))
    end
  end

  test "expired? reflects lapses_at boundary" do
    assert_predicate UserReauthSession.new(@valid_params.merge(lapses_at: Time.current)), :expired?
    assert_not UserReauthSession.new(@valid_params.merge(lapses_at: 1.second.from_now)).expired?
  end

  test "same actor can have independent token-bound tickets" do
    other_token = UserToken.create!(user: @user)
    first = UserReauthSession.create!(@valid_params)
    second = UserReauthSession.create!(@valid_params.merge(user_token: other_token, return_to: "/other"))

    assert_equal [first, second].sort,
                 UserReauthSession.where(user_token_id: [@user_token.id, other_token.id]).to_a.sort
  end
end
