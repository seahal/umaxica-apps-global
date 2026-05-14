# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_verifications
# Database name: symbol
#
#  id               :bigint           not null, primary key
#  lapses_at        :datetime         default(Infinity), not null
#  last_used_at     :datetime
#  purge_at         :datetime         default(Infinity), not null
#  token_digest     :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  visitor_token_id :bigint           not null
#
# Indexes
#
#  index_visitor_verifications_on_token_digest      (token_digest) UNIQUE
#  index_visitor_verifications_on_visitor_token_id  (visitor_token_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_token_id => visitor_tokens.id)
#
require "test_helper"

class VisitorVerificationTest < ActiveSupport::TestCase
  setup do
    ensure_visitor_reference_records!
    ensure_visitor_token_reference_records!
    @visitor = Visitor.create!
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
  end

  test "active? reflects revoked and expiry state" do
    verification =
      travel_to(10.minutes.ago) do
        VisitorVerification.create!(
          visitor_token: @token,
          token_digest: VisitorVerification.digest_token("raw"),
          lapses_at: 1.hour.from_now,
          last_used_at: Time.current,
        )
      end

    assert_predicate verification, :active?

    verification.update_columns(lapses_at: 1.minute.ago)

    assert_not verification.active?
  end

  test "issue_for_token! revokes previous active verification" do
    previous, = VisitorVerification.issue_for_token!(token: @token)

    replacement, raw_token = VisitorVerification.issue_for_token!(token: @token)

    assert_predicate raw_token, :present?
    assert_predicate replacement, :active?
    assert_predicate previous.reload.lapses_at, :present?
  end

  private

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorStatus.find_or_create_by!(id: VisitorStatus::RESERVED)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::NOBODY)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::STAFF)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::BOTH)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenStatus.ensure_defaults!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end
end
