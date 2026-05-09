# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_verifications
# Database name: token
#
#  id             :bigint           not null, primary key
#  lapses_at      :datetime         default(Infinity), not null
#  last_used_at   :datetime
#  purge_at       :datetime         default(Infinity), not null
#  token_digest   :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  staff_token_id :bigint           not null
#
# Indexes
#
#  index_staff_verifications_on_staff_token_id  (staff_token_id)
#  index_staff_verifications_on_token_digest    (token_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_token_id => staff_tokens.id) ON DELETE => cascade
#
require "test_helper"

class StaffVerificationTest < ActiveSupport::TestCase
  fixtures :staffs, :staff_tokens

  test "issue_for_token! revokes previous active verification for same token" do
    token = staff_tokens(:one)
    first, = StaffVerification.issue_for_token!(token: token)
    second, raw = StaffVerification.issue_for_token!(token: token)

    assert_predicate first.reload.lapses_at, :present?
    assert_predicate second, :active?
    assert_equal StaffVerification.digest_token(raw), second.token_digest
  end

  test "active scope only returns non-revoked and non-expired verifications" do
    token = staff_tokens(:one)
    active, = StaffVerification.issue_for_token!(token: token)
    expired = StaffVerification.create!(
      staff_token: token,
      token_digest: SecureRandom.hex(48),
      lapses_at: 1.minute.ago,
    )

    ids = StaffVerification.active.pluck(:id)

    assert_includes ids, active.id
    assert_not_includes ids, expired.id
  end
end
