# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageBoosterV2Test < ActionDispatch::IntegrationTest
  setup do
    https!
    [1, 2, 3].each { |id| CustomerStatus.find_or_create_by!(id: id) }
    [0, 1, 2, 3].each { |id| CustomerVisibility.find_or_create_by!(id: id) }
    CustomerEmailStatus.find_or_create_by!(id: CustomerEmailStatus::VERIFIED)
    CustomerEmailStatus.find_or_create_by!(id: CustomerEmailStatus::UNVERIFIED_WITH_SIGN_UP)
    CustomerEmailStatus.find_or_create_by!(id: CustomerEmailStatus::VERIFIED_WITH_SIGN_UP)
    CloudflareTurnstile.test_mode = true
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "boost EmailsController JSON and edge cases" do
    host! "id.com.localhost"

    CloudflareTurnstile.test_validation_response = { "success" => true }

    # We need to create a record first so update has something to patch
    customer = Customer.create!(status_id: CustomerStatus::ACTIVE, visibility_id: CustomerVisibility::CUSTOMER)
    email = CustomerEmail.create!(
      customer: customer,
      address: "test-in-json@example.com",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
      confirm_policy: "1",
    )

    post "/sign/in/email", params: { user_email: { address: email.address }, "cf-turnstile-response": "test_success" }

    assert_response :redirect

    patch "/sign/in/email", params: { user_email: { pass_code: "" } }, as: :json

    assert_response :unprocessable_content
    assert_equal "application/json", response.media_type

    patch "/sign/in/email", params: { user_email: { pass_code: "000000" } }, as: :json

    assert_response :unprocessable_content
    assert_equal "application/json", response.media_type

    # 3. Session expired in load_user_email
    get "/sign/in/email/edit"

    # 4. Turnstile failure
    CloudflareTurnstile.test_validation_response = { "success" => false }
    post "/sign/in/email", params: { user_email: { address: "test@example.com" } }

    assert_response :unprocessable_content

    post "/sign/up/emails", params: { user_email: { raw_address: "test@example.com", confirm_policy: "1" } }

    assert_response :unprocessable_content
  end
end
