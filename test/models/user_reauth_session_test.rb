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
#  method        :string           not null
#  purge_at      :datetime         default(Infinity), not null
#  return_to     :text             not null
#  scope         :string           not null
#  status        :string           not null
#  verified_at   :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_user_reauth_sessions_on_user_id_and_status  (user_id,status)
#
require "test_helper"

class UserReauthSessionTest < ActiveSupport::TestCase
  test "expired? reflects expires_at" do
    user = User.create!(status_id: UserStatus::ACTIVE, visibility_id: UserVisibility::BOTH)

    session = UserReauthSession.new(
      user: user,
      scope: "account_update",
      return_to: "/account",
      method: "passkey",
      status: "PENDING",
      lapses_at: 1.second.ago,
    )

    assert_predicate session, :expired?
  end
end
