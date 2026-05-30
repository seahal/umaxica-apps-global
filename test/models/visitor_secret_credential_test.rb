# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_secret_credentials
# Database name: com_principal
#
#  id                                  :bigint           not null, primary key
#  discarded_at                        :datetime         default(Infinity), not null
#  last_used_at                        :datetime
#  name                                :string           default(""), not null
#  password_digest                     :string           default(""), not null
#  purged_at                           :datetime         default(Infinity), not null
#  uses_remaining                      :integer          default(1), not null
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  public_id                           :string(21)       not null
#  visitor_id                          :bigint           not null
#  visitor_secret_credential_kind_id   :bigint           default(1), not null
#  visitor_secret_credential_status_id :bigint           default(1), not null
#
# Indexes
#
#  idx_on_visitor_secret_credential_kind_id_80c2fa07fe    (visitor_secret_credential_kind_id)
#  idx_on_visitor_secret_credential_status_id_a8132e5a1a  (visitor_secret_credential_status_id)
#  index_visitor_secret_credentials_on_public_id          (public_id) UNIQUE
#  index_visitor_secret_credentials_on_visitor_id         (visitor_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_id => visitors.id)
#  fk_rails_...  (visitor_secret_credential_kind_id => visitor_secret_credential_kinds.id)
#  fk_rails_...  (visitor_secret_credential_status_id => visitor_secret_credential_statuses.id)
#
require "test_helper"

class VisitorSecretCredentialTest < ActiveSupport::TestCase
  setup do
    ensure_visitor_reference_records!
    @visitor = create_verified_visitor_with_email
    @password = "a" * 32
    @valid_params = {
      visitor: @visitor,
      name: "My Secret",
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      discarded_at: 1.year.from_now,
      uses_remaining: 1,
    }.freeze
  end

  test "is valid with valid parameters" do
    secret_credential = VisitorSecretCredential.new(@valid_params)
    secret_credential.password = @password

    assert_predicate secret_credential, :valid?
  end

  test "is invalid without password" do
    secret_credential = VisitorSecretCredential.new(@valid_params.merge(password: nil))

    assert_not secret_credential.valid?
    assert_predicate secret_credential.errors[:password_digest], :any?
  end

  test "enforces secret_credential limit" do
    Prosopite.pause do
      VisitorSecretCredential::MAX_SECRETS_PER_VISITOR.times do |i|
        VisitorSecretCredential.issue!(name: "Secret #{i}", visitor: @visitor)
      end
    end

    extra = VisitorSecretCredential.new(@valid_params.merge(name: "Extra"))
    extra.password = @password

    assert_not extra.valid?
    assert_includes extra.errors[:base],
                    "exceeds maximum secret_credentials per visitor (#{VisitorSecretCredential::MAX_SECRETS_PER_VISITOR})"
  end

  test "requires verified recovery identity on create" do
    unverified_visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::BOTH,
    )
    secret_credential = VisitorSecretCredential.new(@valid_params.merge(visitor: unverified_visitor))
    secret_credential.password = @password

    assert_not secret_credential.valid?
    assert_includes secret_credential.errors[:base], Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "usable_for_secret_credential_sign_in?" do
    secret_credential, _ = VisitorSecretCredential.issue!(name: "Usable", visitor: @visitor)

    assert_predicate secret_credential, :usable_for_secret_credential_sign_in?

    secret_credential.update!(visitor_secret_credential_status_id: VisitorSecretCredentialStatus::NOTHING)

    assert_not secret_credential.usable_for_secret_credential_sign_in?
  end

  test "verify_for_secret_credential_sign_in! for one-time secret_credential" do
    secret_credential, raw = VisitorSecretCredential.issue!(
      name: "One Time",
      visitor: @visitor,
      uses: 1,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::ONE_TIME,
    )

    assert secret_credential.verify_for_secret_credential_sign_in!(raw)
    assert_equal 0, secret_credential.reload.uses_remaining
    assert_equal VisitorSecretCredentialStatus::USED, secret_credential.visitor_secret_credential_status_id
  end

  test "usable_for_secret_credential_sign_in? rejects exhausted one-time secret_credential" do
    secret_credential, = VisitorSecretCredential.issue!(
      name: "Exhausted Usable",
      visitor: @visitor,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::ONE_TIME,
      uses: 0,
    )

    assert_not secret_credential.usable_for_secret_credential_sign_in?
  end

  test "verify_for_secret_credential_sign_in! fails with wrong password" do
    secret_credential, _ = VisitorSecretCredential.issue!(name: "Wrong", visitor: @visitor)

    assert_not secret_credential.verify_for_secret_credential_sign_in!("wrong-password")
  end

  test "expired_for_secret_credential_sign_in?" do
    secret_credential, _ = VisitorSecretCredential.issue!(
      name: "Expired", visitor: @visitor,
      discarded_at: 1.second.ago,
    )

    assert_not secret_credential.usable_for_secret_credential_sign_in?
  end

  test "allowed_for_secret_credential_sign_in scope" do
    VisitorSecretCredential.issue!(name: "Allowed", visitor: @visitor)
    VisitorSecretCredential.issue!(name: "Not Allowed", visitor: @visitor, status: :nothing)

    assert_equal 1, VisitorSecretCredential.allowed_for_secret_credential_sign_in.count
  end

  test "kind predicates reflect the visitor_secret_credential_kind_id" do
    secret_credential = VisitorSecretCredential.new(@valid_params.merge(visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN))

    assert_predicate secret_credential, :login_secret_credential?
    assert_predicate secret_credential, :permanent_secret_credential?
    assert_not secret_credential.recovery_secret_credential?
    assert_not secret_credential.api_secret_credential?
    assert_not secret_credential.one_time_secret_credential?

    secret_credential.visitor_secret_credential_kind_id = VisitorSecretCredentialKind::RECOVERY

    assert_predicate secret_credential, :recovery_secret_credential?
    assert_predicate secret_credential, :one_time_secret_credential?

    secret_credential.visitor_secret_credential_kind_id = VisitorSecretCredentialKind::API

    assert_predicate secret_credential, :api_secret_credential?
  end

  test "value aliases password and to_param returns public id" do
    secret_credential, = VisitorSecretCredential.issue!(name: "Value Alias", visitor: @visitor)
    generated = VisitorSecretCredential.generate_raw_secret_credential(length: 24)

    secret_credential.value = generated

    assert_equal 24, generated.length
    assert_equal generated, secret_credential.value
    assert secret_credential.authenticate(generated)
    assert_equal secret_credential.public_id, secret_credential.to_param
  end

  test "verify_for_secret_credential_sign_in! rejects disallowed kind status expiry and exhausted use" do
    inactive, inactive_raw = VisitorSecretCredential.issue!(name: "Inactive", visitor: @visitor, status: :nothing)
    api, api_raw = VisitorSecretCredential.issue!(
      name: "API",
      visitor: @visitor,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::API,
    )
    expired, expired_raw = VisitorSecretCredential.issue!(
      name: "Expired Secret", visitor: @visitor,
      discarded_at: 1.second.ago,
    )
    exhausted, exhausted_raw = VisitorSecretCredential.issue!(
      name: "Exhausted",
      visitor: @visitor,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::ONE_TIME,
      uses: 0,
    )

    assert_not inactive.verify_for_secret_credential_sign_in!(inactive_raw)
    assert_not api.verify_for_secret_credential_sign_in!(api_raw)
    assert_not expired.verify_for_secret_credential_sign_in!(expired_raw)
    assert_not exhausted.verify_for_secret_credential_sign_in!(exhausted_raw)
  end
end
