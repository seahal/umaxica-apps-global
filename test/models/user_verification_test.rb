# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_verifications
# Database name: mark
#
#  id            :bigint           not null, primary key
#  lapses_at     :datetime         default(Infinity), not null
#  last_used_at  :datetime
#  purge_at      :datetime         default(Infinity), not null
#  token_digest  :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_token_id :bigint           not null
#
# Indexes
#
#  index_user_verifications_on_token_digest   (token_digest) UNIQUE
#  index_user_verifications_on_user_token_id  (user_token_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_token_id => user_tokens.id) ON DELETE => cascade
#
require "test_helper"

class UserVerificationTest < ActiveSupport::TestCase
  fixtures :users, :user_tokens

  test "issue_for_token! revokes previous active verification for same token" do
    token = user_tokens(:one)
    first, = UserVerification.issue_for_token!(token: token)
    second, raw = UserVerification.issue_for_token!(token: token)

    assert_predicate first.reload.lapses_at, :present?
    assert_predicate second, :active?
    assert_equal UserVerification.digest_token(raw), second.token_digest
  end

  test "active scope only returns non-revoked and non-expired verifications" do
    token = user_tokens(:one)
    active, = UserVerification.issue_for_token!(token: token)
    expired = UserVerification.create!(
      user_token: token,
      token_digest: SecureRandom.hex(48),
      lapses_at: 1.minute.ago,
    )

    ids = UserVerification.active.pluck(:id)

    assert_includes ids, active.id
    assert_not_includes ids, expired.id
  end
end
