# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::Dev::R18::SmokeTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "app.localhost")
    host! @host
  end

  test "open R18 smoke page redirects anonymous GET to acme dev confirmation gate" do
    get acme_app___dev_r18_open_url(ri: "jp"), headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal "/__dev/r18/gate", URI.parse(response.location).path
  end

  test "open R18 smoke page allows anonymous GET after acknowledged cookie" do
    post acme_app___dev_r18_gate_url(ri: "jp"),
         params: { pt: acme_app___dev_r18_open_path(ri: "jp") },
         headers: browser_headers.merge("Host" => @host)

    follow_redirect!

    assert_response :success
    assert_equal "open r18 ok", response.body
  end

  test "open R18 smoke page forbids anonymous POST instead of redirecting" do
    post acme_app___dev_r18_open_url(ri: "jp"), headers: browser_headers.merge("Host" => @host)

    assert_response :forbidden
  end

  test "private R18 smoke page redirects anonymous GET to sign in before R18 gate" do
    get acme_app___dev_r18_private_url(ri: "jp"), headers: host_headers(@host)

    assert_response :unprocessable_content
    assert_includes response.body, "Invalid request"
  end

  test "private R18 smoke page allows logged in adult with allow preference" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    create_r18_preference!(user, ClientPreferenceR18DisplayStopperOption::APPROVED)

    get acme_app___dev_r18_private_url(ri: "jp"), headers: as_user_headers(user, host: @host)

    assert_response :success
    assert_equal "private r18 ok", response.body
  end

  test "private R18 smoke page forbids logged in POST instead of redirecting" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    create_r18_preference!(user, ClientPreferenceR18DisplayStopperOption::APPROVED)

    post acme_app___dev_r18_private_url(ri: "jp"), headers: as_user_headers(user, host: @host)

    assert_response :forbidden
  end

  private

  def create_r18_preference!(user, option_id)
    ClientPreferenceR18DisplayStopperOption.ensure_defaults!
    preference = ClientPreference.create!(user: user)
    ClientPreferenceR18DisplayStopper.create!(preference: preference, option_id: option_id)
    preference
  end
end
