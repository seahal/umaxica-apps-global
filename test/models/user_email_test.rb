# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_emails
# Database name: principal
#
#  id                        :bigint           not null, primary key
#  address                   :string           default(""), not null
#  address_bidx              :string
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
#  user_email_status_id      :bigint           default(1), not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_user_emails_on_address_bidx            (address_bidx) UNIQUE WHERE (address_bidx IS NOT NULL)
#  index_user_emails_on_address_digest          (address_digest) UNIQUE WHERE (address_digest IS NOT NULL)
#  index_user_emails_on_otp_last_sent_at        (otp_last_sent_at)
#  index_user_emails_on_public_id               (public_id) UNIQUE
#  index_user_emails_on_user_email_status_id    (user_email_status_id)
#  index_user_emails_on_user_id                 (user_id)
#  index_user_identity_emails_on_lower_address  (lower((address)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_email_status_id => user_email_statuses.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class UserEmailTest < ActiveSupport::TestCase
  fixtures :users, :user_statuses, :user_email_statuses

  setup do
    @user = users(:none_user)
    @valid_attributes = {
      address: "test@example.com",
      confirm_policy: true,
      user: @user,
    }.freeze
  end

  test "should inherit from PrincipalRecord" do
    assert_operator UserEmail, :<, PrincipalRecord
  end

  test "should include Email concern" do
    assert_includes UserEmail.included_modules, Email
  end

  test "should include Turnstile concern" do
    assert_includes UserEmail.included_modules, Turnstile
  end

  test "turnstile validation runs when required and surface custom message" do
    Turnstile.test_response = { "success" => false }

    user_email = UserEmail.new(@valid_attributes)
    user_email.require_turnstile(
      response: "test-token",
      remote_ip: "127.0.0.1",
      error_message: "Turnstile failed",
    )

    assert_not user_email.turnstile_valid?
    assert_not user_email.valid?
    assert_includes user_email.errors[:base], "Turnstile failed"
  ensure
    Turnstile.test_response = nil
  end

  test "should be valid with valid email and policy confirmation" do
    user_email = UserEmail.new(@valid_attributes)

    assert_predicate user_email, :valid?
  end

  test "should require valid email format" do
    user_email = UserEmail.new(@valid_attributes.merge(address: "invalid-email"))

    assert_not user_email.valid?
    assert_not_empty user_email.errors[:address]
  end

  test "should require email presence" do
    user_email = UserEmail.new(@valid_attributes.except(:address))
    user_email.address = ""

    assert_not user_email.valid?
    assert_not_empty user_email.errors[:address]
  end

  test "should require policy confirmation" do
    user_email = UserEmail.new(@valid_attributes.merge(confirm_policy: false))

    assert_not user_email.valid?
    assert_not_empty user_email.errors[:confirm_policy]
  end

  test "should require unique email addresses" do
    UserEmail.create!(@valid_attributes)
    duplicate_email = UserEmail.new(@valid_attributes)

    assert_not duplicate_email.valid?
    assert_not_empty duplicate_email.errors[:address]
  end

  test "sets address_digest from normalized input" do
    user_email = UserEmail.create!(
      raw_address: "TEST@EXAMPLE.COM",
      confirm_policy: true,
      user: @user,
    )

    expected = IdentifierBlindIndex.bidx_for_email("test@example.com")

    assert_equal expected, user_email.address_digest
  end

  test "should downcase email address before saving" do
    user_email = UserEmail.new(@valid_attributes.merge(address: "TEST@EXAMPLE.COM"))
    user_email.save!

    assert_equal "test@example.com", user_email.address
  end

  test "should be valid when pass_code is present and address is valid" do
    user_email = UserEmail.new(address: "test@example.com", pass_code: "123456", user: @user)

    assert_predicate user_email, :valid?
    assert_not user_email.errors[:confirm_policy].any?
  end

  test "should encrypt email address" do
    user_email = UserEmail.create!(@valid_attributes)
    query = "SELECT address FROM #{UserEmail.table_name} WHERE id = '#{user_email.id}'"
    raw_data = UserEmail.connection.execute(query).first
    assert_not_equal @valid_attributes[:address], raw_data["address"] if raw_data
  end

  test "blocks destroying an undeletable email" do
    user_email = UserEmail.create!(@valid_attributes.merge(undeletable: true))

    assert_raises(ActiveRecord::RecordNotDestroyed) { user_email.destroy! }
    assert_includes user_email.errors[:base], "cannot delete a protected email address"
    assert_predicate user_email.reload, :undeletable?
  end

  test "enforces maximum emails per user" do
    user = users(:one)
    Prosopite.pause do
      UserEmail::MAX_EMAILS_PER_USER.times do |i|
        UserEmail.create!(
          address: "user#{i}@example.com",
          confirm_policy: true,
          user: user,
        )
      end
    end

    extra_email = UserEmail.new(
      address: "overflow@example.com",
      confirm_policy: true,
      user: user,
    )

    assert_not extra_email.valid?
    assert_includes extra_email.errors[:base], "exceeds maximum emails per user (#{UserEmail::MAX_EMAILS_PER_USER})"
  end

  test "verification token generation and verification" do
    user_email = UserEmail.create!(@valid_attributes)

    token = user_email.generate_verification_token

    assert_not_nil token
    assert_not_nil user_email.verification_token_digest

    assert user_email.verify_verification_token(token)
    assert_not user_email.verify_verification_token("wrong-token")
    assert_not user_email.verify_verification_token("")
  end
end
