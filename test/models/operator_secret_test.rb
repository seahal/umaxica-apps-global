# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_secrets
# Database name: org_principal
#
#  id                              :bigint           not null, primary key
#  discarded_at                    :datetime         default(Infinity), not null
#  last_used_at                    :datetime
#  name                            :string           not null
#  password_digest                 :string
#  purged_at                       :datetime         default(Infinity), not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  public_id                       :string(21)       not null
#  staff_id                        :bigint           not null
#  staff_identity_secret_status_id :bigint           default(1), not null
#  staff_secret_kind_id            :bigint           default(2), not null
#
# Indexes
#
#  index_staff_secrets_on_public_id                        (public_id) UNIQUE
#  index_staff_secrets_on_staff_id                         (staff_id)
#  index_staff_secrets_on_staff_identity_secret_status_id  (staff_identity_secret_status_id)
#  index_staff_secrets_on_staff_secret_kind_id             (staff_secret_kind_id)
#
# Foreign Keys
#
#  fk_rails_...                              (staff_id => operators.id)
#  fk_rails_...                              (staff_identity_secret_status_id => staff_secret_statuses.id)
#  fk_staff_secrets_on_staff_secret_kind_id  (staff_secret_kind_id => staff_secret_kinds.id)
#

require "test_helper"

class OperatorSecretTest < ActiveSupport::TestCase
  fixtures :operators, :operator_secret_statuses, :operator_secret_kinds

  setup do
    # Set up OperatorSecretKind records
    OperatorSecretKind.find_or_create_by!(id: OperatorSecretKind::NOTHING)
    OperatorSecretKind.find_or_create_by!(id: OperatorSecretKind::LOGIN)

    @staff = Operator.find_by!(public_id: "BCDE2345FGHJ67KM")
  end

  test "allows up to the maximum number of secrets per staff" do
    Prosopite.pause do
      OperatorSecret::MAX_SECRETS_PER_STAFF.times do
        create_secret!
      end
    end

    assert_equal OperatorSecret::MAX_SECRETS_PER_STAFF,
                 OperatorSecret.where(staff: @staff).count
  end

  test "rejects creating more than the maximum secrets per staff" do
    Prosopite.pause { OperatorSecret::MAX_SECRETS_PER_STAFF.times { create_secret! } }

    assert_raises(ActiveRecord::RecordInvalid) { create_secret! }
  end

  test "issue! returns raw secret and persists a digest" do
    record, raw_secret = OperatorSecret.issue!(name: "API Key", staff: @staff, staff_secret_kind_id: OperatorSecretKind::LOGIN)

    assert_predicate record, :persisted?
    assert_predicate raw_secret, :present?
    assert record.authenticate(raw_secret)
    assert_not_includes record.attributes.values, raw_secret
  end

  test "verify_and_consume! marks secret as used after success" do
    record, raw_secret = OperatorSecret.issue!(name: "API Key", staff: @staff, uses: 2, staff_secret_kind_id: OperatorSecretKind::LOGIN)

    assert record.verify_and_consume!(raw_secret)
    assert_equal OperatorSecretStatus::USED, record.reload.staff_secret_status_id
  end

  test "verify_and_consume! marks used when uses_remaining reaches zero" do
    record, raw_secret = OperatorSecret.issue!(name: "API Key", staff: @staff, uses: 1, staff_secret_kind_id: OperatorSecretKind::LOGIN)

    assert record.verify_and_consume!(raw_secret)
    assert_equal OperatorSecretStatus::USED, record.reload.staff_secret_status_id
  end

  test "sample fixture secret authenticates with fixed raw secret" do
    secret = operator_secrets(:sample_login)

    assert secret.authenticate("11111111111111111111111111111111")
    assert_equal OperatorSecretKind::LOGIN, secret.staff_secret_kind_id
    assert_equal OperatorSecretStatus::ACTIVE, secret.staff_secret_status_id
  end

  test "requires name to be present" do
    record = OperatorSecret.new(
      staff: @staff,
      name: "",
      password: "SecretPass123!",
    )

    assert_not record.valid?
    assert record.errors[:name]
  end

  test "validates kind_id is required" do
    record = OperatorSecret.new(
      staff: @staff,
      name: "Test Secret",
      password: secure_secret,
      staff_secret_kind_id: nil,
    )

    assert_not record.valid?
    assert_not_empty record.errors[:staff_secret_kind]
  end

  test "login_secret? predicate returns true for LOGIN kind" do
    record = OperatorSecret.new(staff: @staff, name: "Key", staff_secret_kind_id: OperatorSecretKind::LOGIN)

    assert_predicate record, :login_secret?
  end

  test "permanent_secret? predicate returns true for LOGIN kind" do
    record = OperatorSecret.new(staff: @staff, name: "Key", staff_secret_kind_id: OperatorSecretKind::LOGIN)

    assert_predicate record, :permanent_secret?
    assert_not record.one_time_secret?
  end

  test "usable_for_secret_sign_in? rejects revoked kind and expired secrets" do
    record, _raw_secret = OperatorSecret.issue!(name: "Sign In Secret", staff: @staff, staff_secret_kind_id: OperatorSecretKind::LOGIN)

    assert_predicate record, :usable_for_secret_sign_in?

    record.staff_secret_status_id = OperatorSecretStatus::REVOKED

    assert_not record.usable_for_secret_sign_in?

    record.staff_secret_status_id = OperatorSecretStatus::ACTIVE
    record.staff_secret_kind_id = OperatorSecretKind::NOTHING

    assert_not record.usable_for_secret_sign_in?

    record.staff_secret_kind_id = OperatorSecretKind::LOGIN
    record.define_singleton_method(:expires_at) { 1.minute.ago }

    assert_not record.usable_for_secret_sign_in?
  end

  test "verify_for_secret_sign_in! rejects wrong secret and disallowed states" do
    record, raw_secret = OperatorSecret.issue!(name: "Sign In Secret", staff: @staff, staff_secret_kind_id: OperatorSecretKind::LOGIN)

    assert_not record.verify_for_secret_sign_in!("wrong-secret")

    record.update!(staff_identity_secret_status_id: OperatorSecretStatus::REVOKED)

    assert_not record.verify_for_secret_sign_in!(raw_secret)

    record.update!(
      staff_identity_secret_status_id: OperatorSecretStatus::ACTIVE,
      staff_secret_kind_id: OperatorSecretKind::NOTHING,
    )

    assert_not record.verify_for_secret_sign_in!(raw_secret)
  end

  test "verify_for_secret_sign_in! keeps permanent login secret active" do
    record, raw_secret = OperatorSecret.issue!(name: "Permanent Key", staff: @staff, staff_secret_kind_id: OperatorSecretKind::LOGIN)

    assert record.verify_for_secret_sign_in!(raw_secret)
    assert_equal OperatorSecretStatus::ACTIVE, record.reload.staff_secret_status_id
    assert_predicate record.last_used_at, :present?
  end

  test "verify_for_secret_sign_in! allows repeated use for permanent login secret" do
    record, raw_secret = OperatorSecret.issue!(name: "Permanent Key", staff: @staff, staff_secret_kind_id: OperatorSecretKind::LOGIN)

    assert record.verify_for_secret_sign_in!(raw_secret)
    first_last_used_at = record.reload.last_used_at

    travel 1.second do
      assert record.verify_for_secret_sign_in!(raw_secret)
    end

    record.reload

    assert_equal OperatorSecretStatus::ACTIVE, record.staff_secret_status_id
    assert_operator record.last_used_at, :>, first_last_used_at
  end

  test "allowed_for_secret_sign_in excludes non login secrets" do
    login_secret, = OperatorSecret.issue!(name: "Login Key", staff: @staff, staff_secret_kind_id: OperatorSecretKind::LOGIN)
    non_login_secret, = OperatorSecret.issue!(name: "Inactive Key", staff: @staff, staff_secret_kind_id: OperatorSecretKind::NOTHING)

    assert_includes OperatorSecret.allowed_for_secret_sign_in, login_secret
    assert_not_includes OperatorSecret.allowed_for_secret_sign_in, non_login_secret
  end

  test "usable_for_secret_sign_in? allows records without expires_at column" do
    secret, = OperatorSecret.issue!(name: "Permanent Key", staff: @staff, staff_secret_kind_id: OperatorSecretKind::LOGIN)

    assert_predicate secret, :usable_for_secret_sign_in?
  end

  test "expired_for_secret_sign_in? handles nil infinite and elapsed expires_at values" do
    secret = OperatorSecret.new

    secret.define_singleton_method(:respond_to?) do |name, include_private = false|
      name == :expires_at || super(name, include_private)
    end

    secret.define_singleton_method(:expires_at) { nil }

    assert_not secret.send(:expired_for_secret_sign_in?, Time.current)

    secret.define_singleton_method(:expires_at) { Float::INFINITY }

    assert_not secret.send(:expired_for_secret_sign_in?, Time.current)

    secret.define_singleton_method(:expires_at) { 1.minute.ago }

    assert secret.send(:expired_for_secret_sign_in?, Time.current)
  end

  test "public_id is automatically generated on create" do
    record = OperatorSecret.create!(
      staff: @staff,
      name: "Test Secret",
      password: secure_secret,
      staff_secret_kind_id: OperatorSecretKind::LOGIN,
    )

    assert_predicate record.public_id, :present?
    assert_equal 21, record.public_id.length
  end

  test "to_param returns public_id" do
    record = OperatorSecret.create!(
      staff: @staff,
      name: "Test Secret",
      password: secure_secret,
      staff_secret_kind_id: OperatorSecretKind::LOGIN,
    )

    assert_equal record.public_id, record.to_param
  end

  test "public_id is unique" do
    record1 = OperatorSecret.create!(
      staff: @staff,
      name: "Test Secret 1",
      password: secure_secret,
      staff_secret_kind_id: OperatorSecretKind::LOGIN,
    )

    record2 = OperatorSecret.new(
      staff: @staff,
      name: "Test Secret 2",
      password: secure_secret,
      staff_secret_kind_id: OperatorSecretKind::LOGIN,
    )
    record2.public_id = record1.public_id

    assert_not record2.valid?
    assert_not_empty record2.errors[:public_id]
  end

  private

  def create_secret!
    OperatorSecret.create!(
      staff: @staff,
      name: "Secret-#{SecureRandom.hex(4)}",
      password: secure_secret,
      password_confirmation: secure_secret,
      staff_secret_kind_id: OperatorSecretKind::LOGIN,
    )
  end

  def secure_secret
    SecureRandom.base58(Secret::SECRET_PASSWORD_LENGTH)
  end
end
