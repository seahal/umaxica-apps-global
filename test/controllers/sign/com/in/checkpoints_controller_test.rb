# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::In::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    ApplicationRecord.clear_fixed_id_seed_cache!
    @visitor = create_verified_visitor_with_email(email_address: "checkpoint-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+10000000992",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
  end

  test "show without login is rejected" do
    get sign_com_in_checkpoint_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "show without checkpoint state continues to dashboard" do
    get sign_com_in_checkpoint_url(ri: "jp"),
        headers: as_visitor_headers(@visitor, host: @host)

    assert_redirected_to sign_com_dashboard_path(ri: "jp")
  end

  test "show with checkpoint notice state returns success" do
    get sign_com_in_checkpoint_url(ri: "jp"),
        headers: as_visitor_headers(@visitor, host: @host).merge(
          "X-TEST-BULLETIN" => checkpoint_json(issued_at: Time.current.to_i, state: "new"),
        )

    assert_response :success
  end

  test "update refreshes checkpoint state and redirects to show" do
    previous_issued_at = 10.minutes.ago.to_i

    patch sign_com_in_checkpoint_url(ri: "jp"),
          headers: as_visitor_headers(@visitor, host: @host).merge(
            "X-TEST-BULLETIN" => checkpoint_json(issued_at: previous_issued_at, state: "new"),
          )

    assert_redirected_to sign_com_in_checkpoint_path(ri: "jp")
    assert_equal "updated", session[:sign_in_checkpoint]["state"]
    assert_operator session[:sign_in_checkpoint]["issued_at"], :>, previous_issued_at
  end

  test "destroy consumes checkpoint and continues to dashboard with rt" do
    rt = Base64.urlsafe_encode64("/configuration?ri=jp")

    delete sign_com_in_checkpoint_url(ri: "jp", rt: rt),
           headers: as_visitor_headers(@visitor, host: @host).merge(
             "X-TEST-BULLETIN" => checkpoint_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_nil session[:sign_in_checkpoint]
    assert_redirected_to sign_com_dashboard_path(ri: "jp", rt: rt)
  end

  test "destroy without rt redirects to default" do
    delete sign_com_in_checkpoint_url(ri: "jp"),
           headers: as_visitor_headers(@visitor, host: @host).merge(
             "X-TEST-BULLETIN" => checkpoint_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_nil session[:sign_in_checkpoint]
    assert_redirected_to sign_com_dashboard_path(ri: "jp")
  end

  test "expired checkpoint returns timeout" do
    get sign_com_in_checkpoint_url(ri: "jp"),
        headers: as_visitor_headers(@visitor, host: @host).merge(
          "X-TEST-BULLETIN" => checkpoint_json(issued_at: 2.hours.ago.to_i - 1, state: "new"),
        )

    assert_response :request_timeout
  end

  private

  def checkpoint_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "notice", "state" => state }.to_json
  end
end
