# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Up::TelephonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    [1, 2, 3].each { |id| CustomerStatus.find_or_create_by!(id: id) }
    [0, 1, 2, 3].each { |id| CustomerVisibility.find_or_create_by!(id: id) }
    [
      CustomerTelephoneStatus::UNVERIFIED,
      CustomerTelephoneStatus::VERIFIED,
      CustomerTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
      CustomerTelephoneStatus::VERIFIED_WITH_SIGN_UP,
    ].each { |id| CustomerTelephoneStatus.find_or_create_by!(id: id) }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_sign_com_up_telephone_url(ri: "jp"), headers: default_headers

    assert_response :success
  end

  test "create redirects to edit and creates pending customer telephone" do
    assert_difference("Customer.count", 1) do
      assert_difference("CustomerTelephone.count", 1) do
        post sign_com_up_telephones_url(ri: "jp"),
             params: {
               customer_telephone: {
                 raw_number: "+819012300001",
                 confirm_policy: "1",
                 confirm_using_mfa: "1",
               },
               "cf-turnstile-response": "test",
             },
             headers: default_headers
      end
    end

    assert_response :redirect
    telephone = CustomerTelephone.order(:created_at).last

    assert_equal CustomerTelephoneStatus::UNVERIFIED_WITH_SIGN_UP, telephone.customer_telephone_status_id
    assert_includes response.location, "/sign/up/telephones/#{telephone.public_id}/edit"
  end

  test "create with invalid telephone fails" do
    post sign_com_up_telephones_url(ri: "jp"),
         params: {
           customer_telephone: {
             raw_number: "not-a-phone",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
  end

  test "create with turnstile failure returns unprocessable content" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    post sign_com_up_telephones_url(ri: "jp"),
         params: {
           customer_telephone: {
             raw_number: "+819012300002",
             confirm_policy: "1",
             confirm_using_mfa: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
  end

  test "update without a valid session redirects to new" do
    telephone = CustomerTelephone.create!(
      customer: Customer.create!(status_id: CustomerStatus::ACTIVE, visibility_id: CustomerVisibility::CUSTOMER),
      raw_number: "+819012300003",
      confirm_policy: "1",
      confirm_using_mfa: "1",
      customer_telephone_status_id: CustomerTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
      otp_expires_at: 5.minutes.from_now,
    )

    patch sign_com_up_telephone_url(id: telephone.public_id, ri: "jp"),
          params: { customer_telephone: { pass_code: "123456" } },
          headers: default_headers

    assert_redirected_to new_sign_com_up_telephone_path(ri: "jp")
  end

  private

  def default_headers
    { "Host" => host, "HTTPS" => "on" }
  end

  def host
    ENV["ID_CORPORATE_URL"] || "id.com.localhost"
  end
end
