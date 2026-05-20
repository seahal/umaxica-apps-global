# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_telephones
# Database name: app_principal
#
#  id                                :bigint           not null, primary key
#  locked_at                         :datetime         default(-Infinity), not null
#  number                            :string           default(""), not null
#  number_digest                     :string
#  otp_attempts_count                :integer          default(0), not null
#  otp_counter                       :text             default(""), not null
#  otp_expires_at                    :datetime         default(-Infinity), not null
#  otp_private_key                   :string           default(""), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  public_id                         :string(21)       not null
#  user_id                           :bigint           not null
#  user_identity_telephone_status_id :bigint           default(2), not null
#
# Indexes
#
#  index_user_telephones_on_number_digest                      (number_digest) UNIQUE WHERE (number_digest IS NOT NULL)
#  index_user_telephones_on_public_id                          (public_id) UNIQUE
#  index_user_telephones_on_user_id                            (user_id)
#  index_user_telephones_on_user_identity_telephone_status_id  (user_identity_telephone_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (user_identity_telephone_status_id => user_telephone_statuses.id)
#

require "test_helper"

class ClientTelephoneTest < ActiveSupport::TestCase
  fixtures_only :clients, :client_statuses, :client_telephone_statuses

  setup do
    @user = clients(:none_user)
    @valid_attributes = {
      raw_number: "+1234567890",
      confirm_policy: true,
      confirm_using_mfa: true,
      user: @user,
    }.freeze
  end

  # Basic model structure tests
  test "should inherit from AppPrincipalRecord" do
    assert_operator ClientTelephone, :<, AppPrincipalRecord
  end

  test "should include Telephone concern" do
    assert_includes ClientTelephone.included_modules, Telephone
  end

  test "should include Turnstile concern" do
    assert_includes ClientTelephone.included_modules, Turnstile
  end

  test "turnstile validation runs when required and surfaces custom message" do
    Turnstile.test_response = { "success" => false }

    user_telephone = ClientTelephone.new(@valid_attributes)
    user_telephone.require_turnstile(
      response: "test-token",
      remote_ip: "127.0.0.1",
      error_message: "Turnstile failed",
    )

    assert_not user_telephone.valid?
    assert_includes user_telephone.errors[:base], "Turnstile failed"
  ensure
    Turnstile.test_response = nil
  end

  # Telephone concern validation tests
  test "should be valid with valid phone number and policy confirmations" do
    user_telephone = ClientTelephone.new(@valid_attributes)

    assert_predicate user_telephone, :valid?
  end

  test "should require valid phone number format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "invalid!@#"))

    I18n.with_locale(:ja) do
      assert_not user_telephone.valid?
      # Error message will be in the current locale (Japanese)
      assert_includes user_telephone.errors[:number], "はE.164形式（例：+819012345678）である必要があります"
    end
  end

  test "should accept phone number with country code" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+81-90-1234-5678"))

    assert_predicate user_telephone, :valid?
  end

  test "should accept phone number with parentheses" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+1 (555) 123-4567"))

    assert_predicate user_telephone, :valid?
  end

  test "should reject phone number that is too short" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "12"))

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:number], :any?
  end

  test "should reject phone number that is too long" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+1234567890123456789012"))

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:number], :any?
  end

  test "should require policy confirmation" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(confirm_policy: false))

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:confirm_policy], :any?
  end

  test "should require MFA confirmation" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(confirm_using_mfa: false))

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:confirm_using_mfa], :any?
  end

  test "should assign numeric id before creation" do
    user_telephone = ClientTelephone.new(@valid_attributes)

    assert_nil user_telephone.id
    user_telephone.save!

    assert_not_nil user_telephone.id
    assert_kind_of Integer, user_telephone.id
  end

  test "finds by normalized number" do
    user_telephone = ClientTelephone.create!(
      raw_number: "+1 (555) 765-4321",
      confirm_policy: true,
      confirm_using_mfa: true,
      user: @user,
    )

    assert_equal user_telephone,
                 ClientTelephone.find_by(number_digest: IdentifierBlindIndex.bidx_for_telephone("+15557654321"))
    assert_nil ClientTelephone.find_by(number_digest: IdentifierBlindIndex.bidx_for_telephone(""))
  end

  test "number is invalid when blank" do
    @valid_attributes.merge(raw_number: nil).then do |attr|
      ClientTelephone.new(attr).tap do |m|
        assert_not m.valid?
        assert_not_empty m.errors[:number]
      end
    end
  end

  test "number is invalid when empty" do
    @valid_attributes.merge(raw_number: "").then do |attr|
      ClientTelephone.new(attr).tap do |m|
        assert_not m.valid?
        assert_not_empty m.errors[:number]
      end
    end
  end

  test "number is invalid when only whitespace" do
    @valid_attributes.merge(raw_number: "   ").then do |attr|
      ClientTelephone.new(attr).tap do |m|
        assert_not m.valid?
        assert_not_empty m.errors[:number]
      end
    end
  end

  test "number is invalid when too long (exceeding 255)" do
    @valid_attributes.merge(raw_number: "1" * 256).then do |attr|
      ClientTelephone.new(attr).tap do |m|
        assert_not m.valid?
        assert_not_empty m.errors[:number]
      end
    end
  end

  test "association: belongs_to user" do
    phone = ClientTelephone.create!(@valid_attributes)

    assert_equal @user, phone.user
  end

  test "association deletion: cleanup when user is destroyed" do
    phone = ClientTelephone.create!(@valid_attributes)
    @user.destroy
    assert_raise(ActiveRecord::RecordNotFound) { phone.reload }
  end

  test "enforce_user_telephone_limit validation on create" do
    # Create maximum allowed telephones
    Prosopite.pause do
      ClientTelephone::MAX_TELEPHONES_PER_USER.times do |i|
        ClientTelephone.create!(@valid_attributes.merge(raw_number: "+155512310#{i}"))
      end
    end

    # Try to create one more
    extra_phone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+15559999999"))

    assert_not extra_phone.valid?
    assert_includes extra_phone.errors[:base], "exceeds maximum telephones per user (#{ClientTelephone::MAX_TELEPHONES_PER_USER})"
  end

  # E.164 normalization tests
  test "normalizes domestic Japanese number to E.164 format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "090-1234-5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "normalizes number with spaces to E.164 format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "090 1234 5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "normalizes number with parentheses to E.164 format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "(090)1234-5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "normalizes international prefix 00 to E.164 format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "0081 90 1234 5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "normalizes international prefix 010 to E.164 format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "010 81 90 1234 5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "removes domestic 0 after country code from international prefix" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "0081(0)90-1234-5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "preserves already E.164 formatted number" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+819012345678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  # E.164 validation error tests
  test "rejects number without leading 0 or + (ambiguous domestic)" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "9012345678"))

    assert_not user_telephone.valid?
    assert_includes user_telephone.errors[:number], I18n.t("activerecord.errors.messages.invalid_e164_format")
  end

  test "rejects number with country code starting with 0" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+0123456789"))

    assert_not user_telephone.valid?
    expected_error = I18n.t("activerecord.errors.messages.country_code_cannot_start_with_zero")

    assert_includes user_telephone.errors[:number], expected_error
  end

  test "rejects number exceeding E.164 maximum length" do
    # E.164 allows max 15 digits (excluding +)
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+1234567890123456")) # 16 digits

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:number], :any?
  end

  test "rejects number with only formatting characters" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "(---)"))

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:number], :any?
  end

  test "accepts maximum length E.164 number" do
    # E.164 max: +[15 digits]
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+999999999999999"))

    assert_predicate user_telephone, :valid?
    assert_equal "+999999999999999", user_telephone.number
  end

  test "handles full-width characters in normalization" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "（090）1234　5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "uniqueness validation on normalized number" do
    # Create first telephone
    ClientTelephone.create!(@valid_attributes.merge(raw_number: "+819012345678"))

    # Try to create with same number but different formatting
    duplicate = ClientTelephone.new(@valid_attributes.merge(raw_number: "090-1234-5678"))

    assert_not duplicate.valid?
    assert_predicate duplicate.errors[:number], :any?
  end

  test "sets number_digest from normalized input" do
    user_telephone = ClientTelephone.create!(
      raw_number: "090-1234-5678",
      confirm_policy: true,
      confirm_using_mfa: true,
      user: @user,
    )

    expected = IdentifierBlindIndex.bidx_for_telephone("+819012345678")

    assert_equal expected, user_telephone.number_digest
  end
end
