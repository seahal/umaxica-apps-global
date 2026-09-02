# typed: false
# frozen_string_literal: true

require "test_helper"

class Core::Com::Api::V0::SessionsControllerTest < ActionDispatch::IntegrationTest
  HOST = ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")

  setup do
    @previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    host! HOST
    https!
  end

  teardown do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = @previous_flag
    Actor.clear if defined?(Actor)
  end

  test "an anonymous com session summary has no actor" do
    get "/api/v0/session", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert_not body.fetch("authenticated")
    assert_predicate body.fetch("csrf_token"), :present?
    assert_not body.key?("actor")
  end

  test "an authenticated com session identifies the visitor by public id" do
    visitor = visitors(:reserved_visitor)
    token_record = VisitorToken.create!(
      visitor_id: visitor.id,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    cookies[CoreBrowserCredentialContract::ACCESS_COOKIE] = CoreBrowserCredentialContract.encode_access_token(
      resource: visitor,
      token_record: token_record,
      host: HOST,
      resource_type: "visitor",
    )

    get "/api/v0/session", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert body.fetch("authenticated")
    assert_equal visitor.public_id, body.fetch("actor").fetch("id")
    assert_not_equal visitor.id.to_s, body.fetch("actor").fetch("id")
  end

  test "a blank visitor public id fails loudly rather than falling back to the database key" do
    visitor = visitors(:reserved_visitor)
    visitor.update_columns(public_id: "")
    token_record = VisitorToken.create!(
      visitor_id: visitor.id,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    cookies[CoreBrowserCredentialContract::ACCESS_COOKIE] = CoreBrowserCredentialContract.encode_access_token(
      resource: visitor,
      token_record: token_record,
      host: HOST,
      resource_type: "visitor",
    )

    assert_raises(BlankPublicIdentifierError) do
      get("/api/v0/session", headers: json_headers)
    end
  ensure
    visitors(:reserved_visitor).update_columns(public_id: "reserved_visitor")
  end

  private

  def json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Client-Agent" =>
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
  end
end
