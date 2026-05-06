# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_tokens
# Database name: symbol
#
#  id                               :bigint           not null, primary key
#  compromised_at                   :datetime
#  dbsc_challenge                   :text
#  dbsc_challenge_issued_at         :datetime
#  dbsc_public_key                  :jsonb
#  deletable_at                     :datetime         default(Infinity), not null
#  device_id_digest                 :string
#  expired_at                       :datetime
#  last_step_up_at                  :datetime
#  last_step_up_scope               :string
#  last_used_at                     :datetime
#  refresh_expires_at               :datetime         not null
#  refresh_token_digest             :binary
#  refresh_token_generation         :integer          default(0), not null
#  revoked_at                       :datetime
#  rotated_at                       :datetime
#  status                           :string(20)       default("active"), not null
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  customer_id                      :bigint           not null
#  customer_token_binding_method_id :bigint           default(0), not null
#  customer_token_dbsc_status_id    :bigint           default(0), not null
#  customer_token_kind_id           :bigint           default(1), not null
#  customer_token_status_id         :bigint           default(0), not null
#  dbsc_session_id                  :string
#  device_id                        :string           default(""), not null
#  public_id                        :string(21)       default(""), not null
#  refresh_token_family_id          :string
#
# Indexes
#
#  index_customer_tokens_on_compromised_at                    (compromised_at)
#  index_customer_tokens_on_customer_id_and_last_step_up_at   (customer_id,last_step_up_at)
#  index_customer_tokens_on_customer_token_binding_method_id  (customer_token_binding_method_id)
#  index_customer_tokens_on_customer_token_dbsc_status_id     (customer_token_dbsc_status_id)
#  index_customer_tokens_on_customer_token_kind_id            (customer_token_kind_id)
#  index_customer_tokens_on_customer_token_status_id          (customer_token_status_id)
#  index_customer_tokens_on_dbsc_session_id                   (dbsc_session_id) UNIQUE
#  index_customer_tokens_on_deletable_at                      (deletable_at)
#  index_customer_tokens_on_device_id                         (device_id)
#  index_customer_tokens_on_device_id_digest                  (device_id_digest)
#  index_customer_tokens_on_expired_at                        (expired_at)
#  index_customer_tokens_on_public_id                         (public_id) UNIQUE
#  index_customer_tokens_on_refresh_expires_at                (refresh_expires_at)
#  index_customer_tokens_on_refresh_token_digest              (refresh_token_digest) UNIQUE
#  index_customer_tokens_on_refresh_token_family_id           (refresh_token_family_id)
#  index_customer_tokens_on_revoked_at                        (revoked_at)
#  index_customer_tokens_on_status                            (status)
#
# Foreign Keys
#
#  fk_customer_tokens_on_customer_token_binding_method_id  (customer_token_binding_method_id => customer_token_binding_methods.id)
#  fk_customer_tokens_on_customer_token_dbsc_status_id     (customer_token_dbsc_status_id => customer_token_dbsc_statuses.id)
#  fk_customer_tokens_on_customer_token_kind_id            (customer_token_kind_id => customer_token_kinds.id)
#  fk_customer_tokens_on_customer_token_status_id          (customer_token_status_id => customer_token_statuses.id)
#
require "test_helper"

class CustomerTokenTest < ActiveSupport::TestCase
  def setup
    ensure_customer_reference_records!
    ensure_customer_token_reference_records!
    @customer = Customer.create!
    @token = CustomerToken.create!(customer: @customer, customer_token_kind_id: CustomerTokenKind::BROWSER_WEB)
  end

  private

  def ensure_customer_reference_records!
    CustomerStatus.find_or_create_by!(id: CustomerStatus::ACTIVE)
    CustomerStatus.find_or_create_by!(id: CustomerStatus::NOTHING)
    CustomerStatus.find_or_create_by!(id: CustomerStatus::RESERVED)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::NOBODY)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::CUSTOMER)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::STAFF)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::BOTH)
  end

  def ensure_customer_token_reference_records!
    CustomerTokenStatus.find_or_create_by!(id: CustomerTokenStatus::NOTHING)
    CustomerTokenStatus.find_or_create_by!(id: CustomerTokenStatus::ACTIVE)
    CustomerTokenStatus.find_or_create_by!(id: CustomerTokenStatus::EXPIRED)
    CustomerTokenKind.find_or_create_by!(id: CustomerTokenKind::BROWSER_WEB)
    CustomerTokenKind.find_or_create_by!(id: CustomerTokenKind::CLIENT_IOS)
    CustomerTokenKind.find_or_create_by!(id: CustomerTokenKind::CLIENT_ANDROID)
    CustomerTokenBindingMethod.find_or_create_by!(id: CustomerTokenBindingMethod::NOTHING)
    CustomerTokenBindingMethod.find_or_create_by!(id: CustomerTokenBindingMethod::DBSC)
    CustomerTokenBindingMethod.find_or_create_by!(id: CustomerTokenBindingMethod::LEGACY)
    CustomerTokenDbscStatus.find_or_create_by!(id: CustomerTokenDbscStatus::NOTHING)
    CustomerTokenDbscStatus.find_or_create_by!(id: CustomerTokenDbscStatus::PENDING)
    CustomerTokenDbscStatus.find_or_create_by!(id: CustomerTokenDbscStatus::ACTIVE)
    CustomerTokenDbscStatus.find_or_create_by!(id: CustomerTokenDbscStatus::FAILED)
    CustomerTokenDbscStatus.find_or_create_by!(id: CustomerTokenDbscStatus::REVOKE)
  end

  public

  test "inherits from SymbolRecord" do
    assert_operator CustomerToken, :<, SymbolRecord
    assert_operator CustomerToken, :<, ApplicationRecord
    assert_not_operator CustomerToken, :<, TokenRecord
  end

  test "signed ref lookup uses symbol connection owner" do
    assert_equal SymbolRecord, CustomerToken.send(:connection_owner)
  end

  test "belongs to customer" do
    association = CustomerToken.reflect_on_association(:customer)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
  end

  test "can be created with customer" do
    assert_not_nil @token
    assert_equal @customer.id, @token.customer_id
  end

  test "enforces maximum concurrent sessions per customer" do
    customer = Customer.create!

    CustomerToken::MAX_TOTAL_SESSIONS_PER_CUSTOMER.times do
      CustomerToken.create!(customer: customer)
    end

    extra_token = CustomerToken.new(customer: customer)

    assert_not extra_token.valid?
    assert_includes(
      extra_token.errors[:base],
      "exceeds maximum concurrent sessions per customer (#{CustomerToken::MAX_TOTAL_SESSIONS_PER_CUSTOMER})",
    )
  end

  test "rotate_refresh_token! generates token that authenticates" do
    raw = @token.rotate_refresh_token!

    public_id, verifier = CustomerToken.parse_refresh_token(raw)

    assert_equal @token.public_id, public_id
    assert @token.authenticate_refresh_token(verifier)
    assert_not @token.authenticate_refresh_token("wrong-value")
  end

  test "rotated replacement preserves forced logout window" do
    freeze_time do
      token = CustomerToken.create!(
        customer: @customer,
        customer_token_kind_id: CustomerTokenKind::BROWSER_WEB,
        revoked_at: 12.hours.from_now,
        deletable_at: 36.hours.from_now,
      )
      token.rotate_refresh_token!

      result = CustomerToken.rotate_refresh!(
        presented_refresh_digest: token.refresh_token_digest,
        device_id: token.device_id,
        now: Time.current,
      )
      replacement = result[:token]

      assert_equal :rotated, result[:status]
      assert_equal token.revoked_at.to_i, replacement.revoked_at.to_i
      assert_equal token.deletable_at.to_i, replacement.deletable_at.to_i
    end
  end
end
