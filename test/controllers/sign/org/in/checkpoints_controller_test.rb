# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Org::In::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = staffs(:one)
  end

  test "show without login is rejected" do
    get sign_org_in_checkpoint_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "show without bulletin continues to dashboard" do
    get sign_org_in_checkpoint_url(ri: "jp"),
        headers: as_staff_headers(@staff, host: @host)

    assert_redirected_to sign_org_dashboard_path(ri: "jp")
  end

  test "show with bulletin returns success" do
    get sign_org_in_checkpoint_url(ri: "jp"),
        headers: as_staff_headers(@staff, host: @host).merge(
          "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new"),
        )

    assert_response :success
  end

  test "update refreshes state and issued_at then redirects to show" do
    previous_issued_at = 10.minutes.ago.to_i

    patch sign_org_in_checkpoint_url(ri: "jp"),
          headers: as_staff_headers(@staff, host: @host).merge(
            "X-TEST-BULLETIN" => bulletin_json(issued_at: previous_issued_at, state: "new"),
          )

    assert_redirected_to sign_org_in_checkpoint_path(ri: "jp")
    assert_equal "updated", session[:sign_in_checkpoint]["state"]
    assert_operator session[:sign_in_checkpoint]["issued_at"], :>, previous_issued_at
  end

  test "destroy consumes bulletin and continues to dashboard with rt" do
    rt = Base64.urlsafe_encode64("/configuration")

    delete sign_org_in_checkpoint_url(ri: "jp", rt: rt),
           headers: as_staff_headers(@staff, host: @host).merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_nil session[:sign_in_checkpoint]
    assert_redirected_to sign_org_dashboard_path(ri: "jp", rt: rt)
  end

  test "destroy without rt redirects to default" do
    delete sign_org_in_checkpoint_url(ri: "jp"),
           headers: as_staff_headers(@staff, host: @host).merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_nil session[:sign_in_checkpoint]
    assert_redirected_to sign_org_dashboard_path(ri: "jp")
  end

  test "show and update return timeout when expired" do
    expired_at = 2.hours.ago.to_i - 1

    get sign_org_in_checkpoint_url(ri: "jp"),
        headers: as_staff_headers(@staff, host: @host).merge(
          "X-TEST-BULLETIN" => bulletin_json(issued_at: expired_at, state: "new"),
        )

    assert_response :request_timeout

    patch sign_org_in_checkpoint_url(ri: "jp"),
          headers: as_staff_headers(@staff, host: @host)

    assert_response :request_timeout
  end

  test "destroy still redirects when expired" do
    rt = Base64.urlsafe_encode64("/configuration")

    delete sign_org_in_checkpoint_url(ri: "jp", rt: rt),
           headers: as_staff_headers(@staff, host: @host).merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: 2.hours.ago.to_i - 1, state: "updated"),
           )

    assert_redirected_to sign_org_dashboard_path(ri: "jp", rt: rt)
  end

  private

  def bulletin_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "mock", "state" => state }.to_json
  end
end
