# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_secrets
# Database name: guest
#
#  id                       :bigint           not null, primary key
#  lapses_at                :datetime         default(Infinity), not null
#  last_used_at             :datetime
#  name                     :string           default(""), not null
#  password_digest          :string           default(""), not null
#  purge_at                 :datetime         default(Infinity), not null
#  uses_remaining           :integer          default(1), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  public_id                :string(21)       not null
#  visitor_id               :bigint           not null
#  visitor_secret_kind_id   :bigint           default(1), not null
#  visitor_secret_status_id :bigint           default(1), not null
#
# Indexes
#
#  index_visitor_secrets_on_public_id                 (public_id) UNIQUE
#  index_visitor_secrets_on_visitor_id                (visitor_id)
#  index_visitor_secrets_on_visitor_secret_kind_id    (visitor_secret_kind_id)
#  index_visitor_secrets_on_visitor_secret_status_id  (visitor_secret_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_id => visitors.id)
#  fk_rails_...  (visitor_secret_kind_id => visitor_secret_kinds.id)
#  fk_rails_...  (visitor_secret_status_id => visitor_secret_statuses.id)
#
require "test_helper"

class VisitorSecretTest < ActiveSupport::TestCase
  setup do
    ensure_visitor_reference_records!
    @visitor = create_verified_visitor_with_email
    @password = "a" * 32
    @valid_params = {
      visitor: @visitor,
      name: "My Secret",
      visitor_secret_status_id: VisitorSecretStatus::ACTIVE,
      visitor_secret_kind_id: VisitorSecretKind::LOGIN,
      lapses_at: 1.year.from_now,
      uses_remaining: 1,
    }.freeze
  end

  test "is valid with valid parameters" do
    secret = VisitorSecret.new(@valid_params)
    secret.password = @password

    assert_predicate secret, :valid?
  end

  test "is invalid without password" do
    secret = VisitorSecret.new(@valid_params.merge(password: nil))

    assert_not secret.valid?
    assert_predicate secret.errors[:password_digest], :any?
  end

  test "enforces secret limit" do
    10.times do |i|
      VisitorSecret.issue!(name: "Secret #{i}", visitor: @visitor)
    end

    extra = VisitorSecret.new(@valid_params.merge(name: "Extra"))
    extra.password = @password

    assert_not extra.valid?
    assert_includes extra.errors[:base], "exceeds maximum secrets per visitor (10)"
  end

  test "requires verified recovery identity on create" do
    unverified_visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::BOTH,
    )
    secret = VisitorSecret.new(@valid_params.merge(visitor: unverified_visitor))
    secret.password = @password

    assert_not secret.valid?
    assert_includes secret.errors[:base], Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "usable_for_secret_sign_in?" do
    secret, _ = VisitorSecret.issue!(name: "Usable", visitor: @visitor)

    assert_predicate secret, :usable_for_secret_sign_in?

    secret.update!(visitor_secret_status_id: VisitorSecretStatus::NOTHING)

    assert_not secret.usable_for_secret_sign_in?
  end

  test "verify_for_secret_sign_in! for one-time secret" do
    secret, raw = VisitorSecret.issue!(
      name: "One Time",
      visitor: @visitor,
      uses: 1,
      visitor_secret_kind_id: VisitorSecretKind::ONE_TIME,
    )

    assert secret.verify_for_secret_sign_in!(raw)
    assert_equal 0, secret.reload.uses_remaining
    assert_equal VisitorSecretStatus::USED, secret.visitor_secret_status_id
  end

  test "usable_for_secret_sign_in? rejects exhausted one-time secret" do
    secret, = VisitorSecret.issue!(
      name: "Exhausted Usable",
      visitor: @visitor,
      visitor_secret_kind_id: VisitorSecretKind::ONE_TIME,
      uses: 0,
    )

    assert_not secret.usable_for_secret_sign_in?
  end

  test "verify_for_secret_sign_in! fails with wrong password" do
    secret, _ = VisitorSecret.issue!(name: "Wrong", visitor: @visitor)

    assert_not secret.verify_for_secret_sign_in!("wrong-password")
  end

  test "expired_for_secret_sign_in?" do
    secret, _ = VisitorSecret.issue!(name: "Expired", visitor: @visitor, lapses_at: 1.second.ago)

    assert_not secret.usable_for_secret_sign_in?
  end

  test "allowed_for_secret_sign_in scope" do
    VisitorSecret.issue!(name: "Allowed", visitor: @visitor)
    VisitorSecret.issue!(name: "Not Allowed", visitor: @visitor, status: :nothing)

    assert_equal 1, VisitorSecret.allowed_for_secret_sign_in.count
  end

  test "kind predicates reflect the visitor_secret_kind_id" do
    secret = VisitorSecret.new(@valid_params.merge(visitor_secret_kind_id: VisitorSecretKind::LOGIN))

    assert_predicate secret, :login_secret?
    assert_predicate secret, :permanent_secret?
    assert_not secret.recovery_secret?
    assert_not secret.api_secret?
    assert_not secret.one_time_secret?

    secret.visitor_secret_kind_id = VisitorSecretKind::RECOVERY

    assert_predicate secret, :recovery_secret?
    assert_predicate secret, :one_time_secret?

    secret.visitor_secret_kind_id = VisitorSecretKind::API

    assert_predicate secret, :api_secret?
  end

  test "value aliases password and to_param returns public id" do
    secret, = VisitorSecret.issue!(name: "Value Alias", visitor: @visitor)
    generated = VisitorSecret.generate_raw_secret(length: 24)

    secret.value = generated

    assert_equal 24, generated.length
    assert_equal generated, secret.value
    assert secret.authenticate(generated)
    assert_equal secret.public_id, secret.to_param
  end

  test "verify_for_secret_sign_in! rejects disallowed kind status expiry and exhausted use" do
    inactive, inactive_raw = VisitorSecret.issue!(name: "Inactive", visitor: @visitor, status: :nothing)
    api, api_raw = VisitorSecret.issue!(
      name: "API",
      visitor: @visitor,
      visitor_secret_kind_id: VisitorSecretKind::API,
    )
    expired, expired_raw = VisitorSecret.issue!(name: "Expired Secret", visitor: @visitor, lapses_at: 1.second.ago)
    exhausted, exhausted_raw = VisitorSecret.issue!(
      name: "Exhausted",
      visitor: @visitor,
      visitor_secret_kind_id: VisitorSecretKind::ONE_TIME,
      uses: 0,
    )

    assert_not inactive.verify_for_secret_sign_in!(inactive_raw)
    assert_not api.verify_for_secret_sign_in!(api_raw)
    assert_not expired.verify_for_secret_sign_in!(expired_raw)
    assert_not exhausted.verify_for_secret_sign_in!(exhausted_raw)
  end
end
