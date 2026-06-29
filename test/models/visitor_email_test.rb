# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_emails
# Database name: com_principal
#
#  id                        :bigint           not null, primary key
#  address                   :string           default(""), not null
#  address_digest            :string
#  discarded_at              :datetime         default(Infinity), not null
#  locked_at                 :datetime         default(Infinity), not null
#  notifiable                :boolean          default(TRUE), not null
#  otp_attempts_count        :integer          default(0), not null
#  otp_counter               :text             default(""), not null
#  otp_expires_at            :datetime         default(-Infinity), not null
#  otp_last_sent_at          :datetime         default(-Infinity), not null
#  otp_private_key           :string           default(""), not null
#  promotional               :boolean          default(TRUE), not null
#  purged_at                 :datetime         default(Infinity), not null
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
#  index_visitor_emails_on_active_address_digest    (address_digest) UNIQUE WHERE ((address_digest IS NOT NULL) AND (visitor_email_status_id <> 4))
#  index_visitor_emails_on_discarded_at             (discarded_at)
#  index_visitor_emails_on_otp_last_sent_at         (otp_last_sent_at)
#  index_visitor_emails_on_public_id                (public_id) UNIQUE
#  index_visitor_emails_on_purged_at                (purged_at)
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

  test "requires email presence" do
    visitor_email = VisitorEmail.new(@valid_attributes.except(:address))
    visitor_email.address = ""

    assert_not visitor_email.valid?
    assert_not_empty visitor_email.errors[:address]
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

  test "deleted sign-up email does not reserve address forever" do
    VisitorEmail.create!(
      @valid_attributes.merge(
        address: "visitor-cancelled-retry@example.com",
        visitor_email_status_id: VisitorEmailStatus::DELETED,
        discarded_at: 1.minute.ago,
        purged_at: 29.minutes.from_now,
      ),
    )
    retry_email = VisitorEmail.new(@valid_attributes.merge(address: "visitor-cancelled-retry@example.com"))

    assert_predicate retry_email, :valid?
    assert_difference "VisitorEmail.count", 1 do
      retry_email.save!
    end
  end

  test "rejects creating more than the maximum emails per visitor" do
    VisitorEmail.where(visitor: @visitor).delete_all
    status = VisitorEmailStatus.find(VisitorEmailStatus::UNVERIFIED)

    VisitorEmail::MAX_EMAILS_PER_VISITOR.times do
      VisitorEmail.create!(
        @valid_attributes.merge(
          address: "limit-#{SecureRandom.hex(4)}@example.com",
          visitor_email_status: status,
        ),
      )
    end

    extra = VisitorEmail.new(
      @valid_attributes.merge(
        address: "limit-extra-#{SecureRandom.hex(4)}@example.com",
        visitor_email_status: status,
      ),
    )

    assert_not extra.valid?
    assert_not_empty extra.errors[:base]
  end
  private

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!

    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    insert_verified_visitor_email!(visitor_id: visitor.id, address: email_address)
    visitor.refresh_mfa_status! if visitor.respond_to?(:refresh_mfa_status!)
    visitor.reload
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [{
        visitor_id: visitor_id,
        address: address,
        address_digest: IdentifierBlindIndex.bidx_for_email(address),
        visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        otp_private_key: SecureRandom.base64(24),
        otp_counter: "",
        otp_attempts_count: 0,
        public_id: SecureRandom.alphanumeric(21),
        created_at: Time.current,
        updated_at: Time.current,
      }],
    )
  end
end
