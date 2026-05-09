# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_secrets
# Database name: guest
#
#  id                        :bigint           not null, primary key
#  lapses_at                 :datetime         default(Infinity), not null
#  last_used_at              :datetime
#  name                      :string           default(""), not null
#  password_digest           :string           default(""), not null
#  purge_at                  :datetime         default(Infinity), not null
#  uses_remaining            :integer          default(1), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  customer_id               :bigint           not null
#  customer_secret_kind_id   :bigint           default(1), not null
#  customer_secret_status_id :bigint           default(1), not null
#  public_id                 :string(21)       not null
#
# Indexes
#
#  index_customer_secrets_on_customer_id                (customer_id)
#  index_customer_secrets_on_customer_secret_kind_id    (customer_secret_kind_id)
#  index_customer_secrets_on_customer_secret_status_id  (customer_secret_status_id)
#  index_customer_secrets_on_public_id                  (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (customer_secret_kind_id => customer_secret_kinds.id)
#  fk_rails_...  (customer_secret_status_id => customer_secret_statuses.id)
#
require "test_helper"

class CustomerSecretTest < ActiveSupport::TestCase
  setup do
    ensure_customer_reference_records!
    @customer = create_verified_customer_with_email
    @password = "a" * 32
    @valid_params = {
      customer: @customer,
      name: "My Secret",
      customer_secret_status_id: CustomerSecretStatus::ACTIVE,
      customer_secret_kind_id: CustomerSecretKind::LOGIN,
      lapses_at: 1.year.from_now,
      uses_remaining: 1,
    }.freeze
  end

  test "is valid with valid parameters" do
    secret = CustomerSecret.new(@valid_params)
    secret.password = @password

    assert_predicate secret, :valid?
  end

  test "is invalid without password" do
    secret = CustomerSecret.new(@valid_params.merge(password: nil))

    assert_not secret.valid?
    assert_predicate secret.errors[:password_digest], :any?
  end

  test "enforces secret limit" do
    10.times do |i|
      CustomerSecret.issue!(name: "Secret #{i}", customer: @customer)
    end

    extra = CustomerSecret.new(@valid_params.merge(name: "Extra"))
    extra.password = @password

    assert_not extra.valid?
    assert_includes extra.errors[:base], "exceeds maximum secrets per customer (10)"
  end

  test "requires verified recovery identity on create" do
    unverified_customer = Customer.create!(
      status_id: CustomerStatus::ACTIVE,
      visibility_id: CustomerVisibility::BOTH,
    )
    secret = CustomerSecret.new(@valid_params.merge(customer: unverified_customer))
    secret.password = @password

    assert_not secret.valid?
    assert_includes secret.errors[:base], Customer::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "usable_for_secret_sign_in?" do
    secret, _ = CustomerSecret.issue!(name: "Usable", customer: @customer)

    assert_predicate secret, :usable_for_secret_sign_in?

    secret.update!(customer_secret_status_id: CustomerSecretStatus::NOTHING)

    assert_not secret.usable_for_secret_sign_in?
  end

  test "verify_for_secret_sign_in! for one-time secret" do
    secret, raw = CustomerSecret.issue!(
      name: "One Time",
      customer: @customer,
      uses: 1,
      customer_secret_kind_id: CustomerSecretKind::ONE_TIME,
    )

    assert secret.verify_for_secret_sign_in!(raw)
    assert_equal 0, secret.reload.uses_remaining
    assert_equal CustomerSecretStatus::USED, secret.customer_secret_status_id
  end

  test "usable_for_secret_sign_in? rejects exhausted one-time secret" do
    secret, = CustomerSecret.issue!(
      name: "Exhausted Usable",
      customer: @customer,
      customer_secret_kind_id: CustomerSecretKind::ONE_TIME,
      uses: 0,
    )

    assert_not secret.usable_for_secret_sign_in?
  end

  test "verify_for_secret_sign_in! fails with wrong password" do
    secret, _ = CustomerSecret.issue!(name: "Wrong", customer: @customer)

    assert_not secret.verify_for_secret_sign_in!("wrong-password")
  end

  test "expired_for_secret_sign_in?" do
    secret, _ = CustomerSecret.issue!(name: "Expired", customer: @customer, lapses_at: 1.second.ago)

    assert_not secret.usable_for_secret_sign_in?
  end

  test "allowed_for_secret_sign_in scope" do
    CustomerSecret.issue!(name: "Allowed", customer: @customer)
    CustomerSecret.issue!(name: "Not Allowed", customer: @customer, status: :nothing)

    assert_equal 1, CustomerSecret.allowed_for_secret_sign_in.count
  end

  test "kind predicates reflect the customer_secret_kind_id" do
    secret = CustomerSecret.new(@valid_params.merge(customer_secret_kind_id: CustomerSecretKind::LOGIN))

    assert_predicate secret, :login_secret?
    assert_predicate secret, :permanent_secret?
    assert_not secret.totp_secret?
    assert_not secret.recovery_secret?
    assert_not secret.api_secret?
    assert_not secret.one_time_secret?

    secret.customer_secret_kind_id = CustomerSecretKind::TOTP

    assert_predicate secret, :totp_secret?

    secret.customer_secret_kind_id = CustomerSecretKind::RECOVERY

    assert_predicate secret, :recovery_secret?
    assert_predicate secret, :one_time_secret?

    secret.customer_secret_kind_id = CustomerSecretKind::API

    assert_predicate secret, :api_secret?
  end

  test "value aliases password and to_param returns public id" do
    secret, = CustomerSecret.issue!(name: "Value Alias", customer: @customer)
    generated = CustomerSecret.generate_raw_secret(length: 24)

    secret.value = generated

    assert_equal 24, generated.length
    assert_equal generated, secret.value
    assert secret.authenticate(generated)
    assert_equal secret.public_id, secret.to_param
  end

  test "verify_for_secret_sign_in! rejects disallowed kind status expiry and exhausted use" do
    inactive, inactive_raw = CustomerSecret.issue!(name: "Inactive", customer: @customer, status: :nothing)
    api, api_raw = CustomerSecret.issue!(
      name: "API",
      customer: @customer,
      customer_secret_kind_id: CustomerSecretKind::API,
    )
    expired, expired_raw = CustomerSecret.issue!(name: "Expired Secret", customer: @customer, lapses_at: 1.second.ago)
    exhausted, exhausted_raw = CustomerSecret.issue!(
      name: "Exhausted",
      customer: @customer,
      customer_secret_kind_id: CustomerSecretKind::ONE_TIME,
      uses: 0,
    )

    assert_not inactive.verify_for_secret_sign_in!(inactive_raw)
    assert_not api.verify_for_secret_sign_in!(api_raw)
    assert_not expired.verify_for_secret_sign_in!(expired_raw)
    assert_not exhausted.verify_for_secret_sign_in!(exhausted_raw)
  end
end
