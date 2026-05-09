# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_secrets
# Database name: operator
#
#  id                              :bigint           not null, primary key
#  lapses_at                       :datetime         default(Infinity), not null
#  last_used_at                    :datetime
#  name                            :string           not null
#  password_digest                 :string
#  purge_at                        :datetime         default(Infinity), not null
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
#  fk_rails_...                              (staff_id => staffs.id)
#  fk_rails_...                              (staff_identity_secret_status_id => staff_secret_statuses.id)
#  fk_staff_secrets_on_staff_secret_kind_id  (staff_secret_kind_id => staff_secret_kinds.id)
#

require "test_helper"

class StaffSecretTest < ActiveSupport::TestCase
  fixtures :staffs, :staff_secret_statuses, :staff_secret_kinds

  setup do
    # Set up StaffSecretKind records
    StaffSecretKind.find_or_create_by!(id: StaffSecretKind::LOGIN)
    StaffSecretKind.find_or_create_by!(id: StaffSecretKind::TOTP)

    @staff = Staff.find_by!(public_id: "BCDE2345FGHJ67KM")
  end

  test "allows up to the maximum number of secrets per staff" do
    Prosopite.pause do
      StaffSecret::MAX_SECRETS_PER_STAFF.times do
        create_secret!
      end
    end

    assert_equal StaffSecret::MAX_SECRETS_PER_STAFF,
                 StaffSecret.where(staff: @staff).count
  end

  test "rejects creating more than the maximum secrets per staff" do
    Prosopite.pause { StaffSecret::MAX_SECRETS_PER_STAFF.times { create_secret! } }

    assert_raises(ActiveRecord::RecordInvalid) { create_secret! }
  end

  test "issue! returns raw secret and persists a digest" do
    record, raw_secret = StaffSecret.issue!(name: "API Key", staff: @staff, staff_secret_kind_id: StaffSecretKind::LOGIN)

    assert_predicate record, :persisted?
    assert_predicate raw_secret, :present?
    assert record.authenticate(raw_secret)
    assert_not_includes record.attributes.values, raw_secret
  end

  test "verify_and_consume! marks secret as used after success" do
    record, raw_secret = StaffSecret.issue!(name: "API Key", staff: @staff, uses: 2, staff_secret_kind_id: StaffSecretKind::LOGIN)

    assert record.verify_and_consume!(raw_secret)
    assert_equal StaffSecretStatus::USED, record.reload.staff_secret_status_id
  end

  test "verify_and_consume! marks used when uses_remaining reaches zero" do
    record, raw_secret = StaffSecret.issue!(name: "API Key", staff: @staff, uses: 1, staff_secret_kind_id: StaffSecretKind::LOGIN)

    assert record.verify_and_consume!(raw_secret)
    assert_equal StaffSecretStatus::USED, record.reload.staff_secret_status_id
  end

  test "sample fixture secret authenticates with fixed raw secret" do
    secret = staff_secrets(:sample_login)

    assert secret.authenticate("11111111111111111111111111111111")
    assert_equal StaffSecretKind::LOGIN, secret.staff_secret_kind_id
    assert_equal StaffSecretStatus::ACTIVE, secret.staff_secret_status_id
  end

  test "requires name to be present" do
    record = StaffSecret.new(
      staff: @staff,
      name: "",
      password: "SecretPass123!",
    )

    assert_not record.valid?
    assert record.errors[:name]
  end

  test "validates kind_id is required" do
    record = StaffSecret.new(
      staff: @staff,
      name: "Test Secret",
      password: secure_secret,
      staff_secret_kind_id: nil,
    )

    assert_not record.valid?
    assert_not_empty record.errors[:staff_secret_kind]
  end

  test "login_secret? predicate returns true for LOGIN kind" do
    record = StaffSecret.new(staff: @staff, name: "Key", staff_secret_kind_id: StaffSecretKind::LOGIN)

    assert_predicate record, :login_secret?
    assert_not record.totp_secret?
  end

  test "totp_secret? predicate returns true for TOTP kind" do
    record = StaffSecret.new(staff: @staff, name: "Key", staff_secret_kind_id: StaffSecretKind::TOTP)

    assert_predicate record, :totp_secret?
    assert_not record.login_secret?
  end

  test "permanent_secret? predicate returns true for LOGIN kind" do
    record = StaffSecret.new(staff: @staff, name: "Key", staff_secret_kind_id: StaffSecretKind::LOGIN)

    assert_predicate record, :permanent_secret?
    assert_not record.one_time_secret?
  end

  test "verify_for_secret_sign_in! keeps permanent login secret active" do
    record, raw_secret = StaffSecret.issue!(name: "Permanent Key", staff: @staff, staff_secret_kind_id: StaffSecretKind::LOGIN)

    assert record.verify_for_secret_sign_in!(raw_secret)
    assert_equal StaffSecretStatus::ACTIVE, record.reload.staff_secret_status_id
    assert_predicate record.last_used_at, :present?
  end

  test "verify_for_secret_sign_in! allows repeated use for permanent login secret" do
    record, raw_secret = StaffSecret.issue!(name: "Permanent Key", staff: @staff, staff_secret_kind_id: StaffSecretKind::LOGIN)

    assert record.verify_for_secret_sign_in!(raw_secret)
    first_last_used_at = record.reload.last_used_at

    travel 1.second do
      assert record.verify_for_secret_sign_in!(raw_secret)
    end

    record.reload

    assert_equal StaffSecretStatus::ACTIVE, record.staff_secret_status_id
    assert_operator record.last_used_at, :>, first_last_used_at
  end

  test "allowed_for_secret_sign_in excludes totp secrets" do
    login_secret, = StaffSecret.issue!(name: "Login Key", staff: @staff, staff_secret_kind_id: StaffSecretKind::LOGIN)
    totp_secret, = StaffSecret.issue!(name: "TOTP Key", staff: @staff, staff_secret_kind_id: StaffSecretKind::TOTP)

    assert_includes StaffSecret.allowed_for_secret_sign_in, login_secret
    assert_not_includes StaffSecret.allowed_for_secret_sign_in, totp_secret
  end

  test "usable_for_secret_sign_in? allows records without expires_at column" do
    secret, = StaffSecret.issue!(name: "Permanent Key", staff: @staff, staff_secret_kind_id: StaffSecretKind::LOGIN)

    assert_predicate secret, :usable_for_secret_sign_in?
  end

  test "expired_for_secret_sign_in? handles nil infinite and elapsed expires_at values" do
    secret = StaffSecret.new

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
    record = StaffSecret.create!(
      staff: @staff,
      name: "Test Secret",
      password: secure_secret,
      staff_secret_kind_id: StaffSecretKind::LOGIN,
    )

    assert_predicate record.public_id, :present?
    assert_equal 21, record.public_id.length
  end

  test "to_param returns public_id" do
    record = StaffSecret.create!(
      staff: @staff,
      name: "Test Secret",
      password: secure_secret,
      staff_secret_kind_id: StaffSecretKind::LOGIN,
    )

    assert_equal record.public_id, record.to_param
  end

  test "public_id is unique" do
    record1 = StaffSecret.create!(
      staff: @staff,
      name: "Test Secret 1",
      password: secure_secret,
      staff_secret_kind_id: StaffSecretKind::LOGIN,
    )

    record2 = StaffSecret.new(
      staff: @staff,
      name: "Test Secret 2",
      password: secure_secret,
      staff_secret_kind_id: StaffSecretKind::LOGIN,
    )
    record2.public_id = record1.public_id

    assert_not record2.valid?
    assert_not_empty record2.errors[:public_id]
  end

  private

  def create_secret!
    StaffSecret.create!(
      staff: @staff,
      name: "Secret-#{SecureRandom.hex(4)}",
      password: secure_secret,
      password_confirmation: secure_secret,
      staff_secret_kind_id: StaffSecretKind::LOGIN,
    )
  end

  def secure_secret
    SecureRandom.base58(Secret::SECRET_PASSWORD_LENGTH)
  end
end
