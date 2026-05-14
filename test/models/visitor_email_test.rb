# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_emails
# Database name: guest
#
#  id                        :bigint           not null, primary key
#  address                   :string           default(""), not null
#  address_digest            :string
#  locked_at                 :datetime         default(Infinity), not null
#  notifiable                :boolean          default(TRUE), not null
#  otp_attempts_count        :integer          default(0), not null
#  otp_counter               :text             default(""), not null
#  otp_expires_at            :datetime         default(-Infinity), not null
#  otp_last_sent_at          :datetime         default(-Infinity), not null
#  otp_private_key           :string           default(""), not null
#  promotional               :boolean          default(TRUE), not null
#  subscribable              :boolean          default(TRUE), not null
#  undeletable               :boolean          default(FALSE), not null
#  verification_token_digest :binary
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  public_id                 :string(21)       not null
#  visitor_email_status_id   :bigint           default(1), not null
#  visitor_id                :bigint           not null
#
# Indexes
#
#  index_visitor_emails_on_address_digest           (address_digest) UNIQUE WHERE (address_digest IS NOT NULL)
#  index_visitor_emails_on_lower_address            (lower((address)::text)) UNIQUE
#  index_visitor_emails_on_otp_last_sent_at         (otp_last_sent_at)
#  index_visitor_emails_on_public_id                (public_id) UNIQUE
#  index_visitor_emails_on_visitor_email_status_id  (visitor_email_status_id)
#  index_visitor_emails_on_visitor_id               (visitor_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_email_status_id => visitor_email_statuses.id)
#  fk_rails_...  (visitor_id => visitors.id)
#
require "test_helper"

class VisitorEmailTest < ActiveSupport::TestCase
  setup do
    @visitor = create_verified_visitor_with_email(
      email_address: "visitor-model-#{SecureRandom.hex(4)}@example.com",
    )
    @valid_attributes = {
      address: "visitor-email@example.com",
      confirm_policy: true,
      visitor: @visitor,
    }.freeze
  end

  test "blocks destroying an undeletable email" do
    visitor_email = VisitorEmail.create!(@valid_attributes.merge(undeletable: true))

    assert_raises(ActiveRecord::RecordNotDestroyed) { visitor_email.destroy! }
    assert_includes visitor_email.errors[:base], "cannot delete a protected email address"
    assert_predicate visitor_email.reload, :undeletable?
  end

  test "verification token can be generated and verified" do
    visitor_email = VisitorEmail.create!(
      @valid_attributes.merge(address: "verify-#{SecureRandom.hex(4)}@example.com"),
    )

    raw_token = visitor_email.generate_verification_token

    assert visitor_email.verify_verification_token(raw_token)
    assert_not visitor_email.verify_verification_token("wrong-token")
  end

  test "verification token fails when token or digest is blank" do
    visitor_email = VisitorEmail.new(@valid_attributes)

    assert_not visitor_email.verify_verification_token("")
    assert_not visitor_email.verify_verification_token("raw-token")
  end

  test "sets address digest from normalized input" do
    visitor_email = VisitorEmail.create!(
      @valid_attributes.merge(address: "VISITOR-DIGEST@example.com"),
    )

    expected = IdentifierBlindIndex.bidx_for_email("visitor-digest@example.com")

    assert_equal expected, visitor_email.address_digest
  end

  test "rejects creating more than the maximum emails per visitor" do
    VisitorEmail.where(visitor: @visitor).delete_all

    VisitorEmail::MAX_EMAILS_PER_VISITOR.times do
      VisitorEmail.create!(@valid_attributes.merge(address: "limit-#{SecureRandom.hex(4)}@example.com"))
    end

    extra = VisitorEmail.new(@valid_attributes.merge(address: "limit-extra-#{SecureRandom.hex(4)}@example.com"))

    assert_not extra.valid?
    assert_not_empty extra.errors[:base]
  end
end
