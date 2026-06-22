# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseRpBrowserFlowTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("BASE_SERVICE_URL", "base.app.localhost"),
      client_id: "base-rails-rp",
      resource: -> { clients(:one) },
    },
    {
      host: ENV.fetch("BASE_STAFF_URL", "base.org.localhost"),
      client_id: "base-rails-rp",
      resource: -> { operators(:one) },
    },
    {
      host: ENV.fetch("BASE_CORPORATE_URL", "base.com.localhost"),
      client_id: "base-rails-rp",
      resource: -> { create_verified_visitor_with_email(email_address: "base-rp-#{SecureRandom.hex(4)}@example.com") },
    },
  ].freeze

  setup do
    load_jump_rt_env!
    ClientIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
  end

  test "base callback routes establish a base rp session" do
    SURFACES.each do |surface|
      host! surface[:host]
      https!

      get "/oidc/authorization", headers: browser_headers

      state = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query).fetch("state")
      resource = instance_exec(&surface[:resource])
      resource_type = oidc_resource_type_for(resource)
      id_token = OidcIdTokenIssuer.call(
        resource: resource,
        client: OidcClientRegistry.find!(surface[:client_id]),
        nonce: session.fetch(:oidc_nonce),
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
        issuer: OidcIssuer.for_resource_type(resource_type),
      )
      token_result = OidcRpTokenClient::Result.new(
        success: true,
        token_response: { id_token: id_token },
        error: nil,
      )

      OidcRpTokenClient.stub(:call, token_result) do
        get "/oidc/callback", params: { code: "code", state: state }, headers: browser_headers
      end

      assert_response :redirect
      assert_equal "https://#{surface[:host]}/", response.location

      get "/dashboard", params: { ri: "jp" }, headers: browser_headers

      assert_response :success
      assert_select "h1", text: "Dashboard"
    end
  end

  private

  def oidc_resource_type_for(resource)
    case resource
    when Client then "client"
    when Operator then "operator"
    when Visitor then "visitor"
    else "client"
    end
  end
end
