# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_reauth_sessions
# Database name: symbol
#
#  id            :bigint           not null, primary key
#  attempt_count :integer          default(0), not null
#  lapses_at     :datetime         default(Infinity), not null
#  method        :string           not null
#  purge_at      :datetime         default(Infinity), not null
#  return_to     :text             not null
#  scope         :string           not null
#  status        :string           not null
#  verified_at   :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  customer_id   :bigint           not null
#
# Indexes
#
#  index_customer_reauth_sessions_on_customer_id_and_status  (customer_id,status)
#
require "test_helper"

class CustomerReauthSessionTest < ActiveSupport::TestCase
  setup do
    ensure_customer_reference_records!
    @customer = Customer.create!(
      status_id: CustomerStatus::ACTIVE,
      visibility_id: CustomerVisibility::BOTH,
    )
    @valid_params = {
      customer: @customer,
      scope: "account_update",
      return_to: "/account",
      method: "passkey",
      status: "PENDING",
      lapses_at: 10.minutes.from_now,
    }.freeze
  end

  test "is valid with valid parameters" do
    session = CustomerReauthSession.new(@valid_params)

    assert_predicate session, :valid?
  end

  test "is invalid without scope" do
    session = CustomerReauthSession.new(@valid_params.merge(scope: nil))

    assert_not session.valid?
    assert_predicate session.errors[:scope], :any?
  end

  test "is invalid without return_to" do
    session = CustomerReauthSession.new(@valid_params.merge(return_to: nil))

    assert_not session.valid?
    assert_predicate session.errors[:return_to], :any?
  end

  test "is invalid with unknown method" do
    session = CustomerReauthSession.new(@valid_params.merge(method: "invalid"))

    assert_not session.valid?
    assert_predicate session.errors[:method], :any?
  end

  test "is invalid with unknown status" do
    session = CustomerReauthSession.new(@valid_params.merge(status: "INVALID"))

    assert_not session.valid?
    assert_predicate session.errors[:status], :any?
  end

  test "is invalid without lapses_at" do
    session = CustomerReauthSession.new(@valid_params.merge(lapses_at: nil))

    assert_not session.valid?
    assert_predicate session.errors[:lapses_at], :any?
  end

  test "expired? returns true if expired" do
    session = CustomerReauthSession.new(@valid_params.merge(lapses_at: 1.second.ago))

    assert_predicate session, :expired?
  end

  test "expired? returns false if not expired" do
    session = CustomerReauthSession.new(@valid_params.merge(lapses_at: 1.minute.from_now))

    assert_not session.expired?
  end

  test "pending scope returns only pending sessions" do
    CustomerReauthSession.create!(@valid_params.merge(status: "PENDING"))
    CustomerReauthSession.create!(@valid_params.merge(status: "VERIFIED"))

    assert_equal 1, CustomerReauthSession.pending.count
    assert_equal "PENDING", CustomerReauthSession.pending.first.status
  end
end
