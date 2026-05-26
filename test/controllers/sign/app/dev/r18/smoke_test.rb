# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Dev::R18::SmokeTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
    host! @host
  end

  test "open R18 smoke page redirects anonymous GET to confirmation gate" do
    get sign_app___dev_r18_open_url(ri: "jp"), headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal "/r18/gate", URI.parse(response.location).path
  end

  test "open R18 smoke page allows anonymous GET after acknowledged cookie" do
    post sign_app_r18_gate_url(ri: "jp"),
         params: { yes: "1", pt: sign_app___dev_r18_open_path(ri: "jp") },
         headers: browser_headers.merge("Host" => @host)

    follow_redirect!

    assert_response :success
    assert_equal "open r18 ok", response.body
  end

  test "open R18 smoke page forbids anonymous POST instead of redirecting" do
    post sign_app___dev_r18_open_url(ri: "jp"), headers: browser_headers.merge("Host" => @host)

    assert_response :forbidden
  end

  test "open R18 confirmation rejects unsafe pt" do
    post sign_app_r18_gate_url(ri: "jp"),
         params: { yes: "1", pt: "https://evil.example/__dev/r18/open" },
         headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_not_equal "evil.example", URI.parse(response.location).host
  end

  test "private R18 smoke page redirects anonymous GET to sign in before R18 gate" do
    get sign_app___dev_r18_private_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_not_equal "/r18/gate", URI.parse(response.location).path
  end

  test "private R18 smoke page blocks logged in underage user even with anonymous acknowledgement" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2010-01-01")
    post sign_app_r18_gate_url(ri: "jp"),
         params: { yes: "1", pt: sign_app___dev_r18_private_path(ri: "jp") },
         headers: browser_headers.merge("Host" => @host)

    get sign_app___dev_r18_private_url(ri: "jp"), headers: as_user_headers(user, host: @host)

    assert_redirected_to blocked_sign_app_r18_gate_url(ri: "jp", host: @host)
  end

  test "private R18 smoke page asks logged in adult with undecided preference" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    create_r18_preference!(user, ClientPreferenceR18DisplayStopperOption::NOTHING)

    get sign_app___dev_r18_private_url(ri: "jp"), headers: as_user_headers(user, host: @host)

    assert_response :redirect
    assert_equal "/r18/gate", URI.parse(response.location).path
  end

  test "private R18 smoke page allows logged in adult with allow preference" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    create_r18_preference!(user, ClientPreferenceR18DisplayStopperOption::APPROVED)

    get sign_app___dev_r18_private_url(ri: "jp"), headers: as_user_headers(user, host: @host)

    assert_response :success
    assert_equal "private r18 ok", response.body
  end

  test "private R18 smoke page stops logged in adult with stopped preference" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    create_r18_preference!(user, ClientPreferenceR18DisplayStopperOption::DENY)

    get sign_app___dev_r18_private_url(ri: "jp"), headers: as_user_headers(user, host: @host)

    assert_redirected_to stopped_sign_app_r18_gate_url(ri: "jp", host: @host)
  end

  test "private R18 smoke page forbids logged in POST instead of redirecting" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    create_r18_preference!(user, ClientPreferenceR18DisplayStopperOption::APPROVED)

    post sign_app___dev_r18_private_url(ri: "jp"), headers: as_user_headers(user, host: @host)

    assert_response :forbidden
  end

  test "rating preference cannot be changed through GET params" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    preference = create_r18_preference!(user, ClientPreferenceR18DisplayStopperOption::DENY)

    get sign_app___dev_r18_private_url(ri: "jp", rating_preference_id: 1),
        headers: as_user_headers(user, host: @host)

    assert_redirected_to stopped_sign_app_r18_gate_url(ri: "jp", host: @host)
    assert_equal ClientPreferenceR18DisplayStopperOption::DENY,
                 preference.client_preference_r18_display_stopper.reload.option_id
  end

  private

  def create_r18_preference!(user, option_id)
    ClientPreferenceR18DisplayStopperOption.ensure_defaults!
    preference = ClientPreference.create!(user: user)
    ClientPreferenceR18DisplayStopper.create!(preference: preference, option_id: option_id)
    preference
  end
end
