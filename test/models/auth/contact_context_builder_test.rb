# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::ContactContextBuilderTest < ActiveSupport::TestCase
  # Load all fixtures to ensure status and visibility records exist
  fixtures :all

  setup do
    ensure_customer_reference_records!

    @user = User.create!(
      status_id: UserStatus::ACTIVE,
      visibility_id: UserVisibility::BOTH,
    )
    @staff = Staff.create!(
      status_id: StaffStatus::ACTIVE,
      visibility_id: StaffVisibility::BOTH,
    )
    @customer = Customer.create!(
      status_id: CustomerStatus::ACTIVE,
      visibility_id: CustomerVisibility::BOTH,
    )
  end

  test "build_for_user with nil user" do
    context = Auth::ContactContextBuilder.build_for_user(nil)

    assert_predicate context, :guest?
    assert_nil context.subject_id
  end

  test "build_for_user with user and verified email" do
    UserEmail.create!(
      user: @user,
      address: "user@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    context = Auth::ContactContextBuilder.build_for_user(@user)

    assert_predicate context, :identified_member?
    assert_equal @user.id.to_s, context.subject_id
    assert_equal "user@example.com", context.email
  end

  test "build_for_user with unverified email fallback" do
    UserEmail.create!(
      user: @user,
      address: "unverified@example.com",
      user_email_status_id: UserEmailStatus::NOTHING,
      confirm_policy: "1",
    )

    context = Auth::ContactContextBuilder.build_for_user(@user)

    assert_equal "unverified@example.com", context.email
  end

  test "build_for_user with verified telephone" do
    UserTelephone.create!(
      user: @user,
      number: "+819011111111",
      user_identity_telephone_status_id: UserTelephoneStatus::VERIFIED,
      confirm_policy: "1",
    )

    context = Auth::ContactContextBuilder.build_for_user(@user)

    assert_equal "+819011111111", context.telephone
  end

  test "build_for_user with unverified telephone fallback" do
    UserTelephone.create!(
      user: @user,
      number: "+819022222222",
      user_identity_telephone_status_id: UserTelephoneStatus::NOTHING,
      confirm_policy: "1",
    )

    context = Auth::ContactContextBuilder.build_for_user(@user)

    assert_equal "+819022222222", context.telephone
  end

  test "build_for_staff with nil" do
    context = Auth::ContactContextBuilder.build_for_staff(nil)

    assert_predicate context, :guest?
  end

  test "build_for_staff with verified telephone" do
    StaffTelephone.create!(
      staff: @staff,
      number: "+819000000000",
      staff_identity_telephone_status_id: StaffTelephoneStatus::VERIFIED,
      confirm_policy: "1",
    )

    context = Auth::ContactContextBuilder.build_for_staff(@staff)

    assert_predicate context, :identified_member?
    assert_equal @staff.id.to_s, context.subject_id
    assert_equal "+819000000000", context.telephone
  end

  test "build_for_staff with unverified telephone fallback" do
    StaffTelephone.create!(
      staff: @staff,
      number: "+819033333333",
      staff_identity_telephone_status_id: StaffTelephoneStatus::NOTHING,
      confirm_policy: "1",
    )

    context = Auth::ContactContextBuilder.build_for_staff(@staff)

    assert_equal "+819033333333", context.telephone
  end

  test "build_for_staff with unverified fallback" do
    StaffEmail.create!(
      staff: @staff,
      address: "staff@example.com",
      staff_identity_email_status_id: StaffEmailStatus::NOTHING,
      confirm_policy: "1",
    )

    context = Auth::ContactContextBuilder.build_for_staff(@staff)

    assert_equal "staff@example.com", context.email
  end

  test "build_for_staff prefers verified email" do
    StaffEmail.create!(
      staff: @staff,
      address: "fallback-staff@example.com",
      staff_identity_email_status_id: StaffEmailStatus::NOTHING,
      confirm_policy: "1",
    )
    StaffEmail.create!(
      staff: @staff,
      address: "verified-staff@example.com",
      staff_identity_email_status_id: StaffEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    context = Auth::ContactContextBuilder.build_for_staff(@staff)

    assert_equal "verified-staff@example.com", context.email
  end

  test "build_for_user prefers sign up verified contacts" do
    UserEmail.create!(
      user: @user,
      address: "signup-user@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED_WITH_SIGN_UP,
      confirm_policy: "1",
    )
    UserTelephone.create!(
      user: @user,
      number: "+819044444444",
      user_identity_telephone_status_id: UserTelephoneStatus::VERIFIED_WITH_SIGN_UP,
      confirm_policy: "1",
    )

    context = Auth::ContactContextBuilder.build_for_user(@user)

    assert_equal "signup-user@example.com", context.email
    assert_equal "+819044444444", context.telephone
  end

  test "build_for_customer with email/telephone response" do
    customer = Struct.new(:id, :email, :telephone).new(123, "customer@example.com", "+819055555555")

    context = Auth::ContactContextBuilder.build_for_customer(customer)

    assert_predicate context, :guest?
    assert_equal "123", context.subject_id
    assert_equal "customer@example.com", context.email
    assert_equal "+819055555555", context.telephone
  end

  test "build_for_customer with nil" do
    context = Auth::ContactContextBuilder.build_for_customer(nil)

    assert_predicate context, :guest?
    assert_nil context.subject_id
  end
end
