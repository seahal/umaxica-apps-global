# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeSelfServiceRoutesTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :operators

  setup do
    @app_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @org_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @com_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
  end

  test "app self service pages require authentication" do
    assert_requires_authentication(acme_app_avatar_url(ri: "jp", host: @app_host), host: @app_host)
    assert_requires_authentication(acme_app_identity_url(ri: "jp", host: @app_host), host: @app_host)
    assert_requires_authentication(acme_app_current_organization_url(ri: "jp", host: @app_host), host: @app_host)
    assert_requires_authentication(acme_app_account_url(ri: "jp", host: @app_host), host: @app_host)
  end

  test "app self service pages render for signed in client" do
    client = clients(:one)
    client.update!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(surface: :app, principal: client, token: token)
    headers = as_user_headers(client, host: @app_host, session_public_id: token.public_id)

    assert_self_service_page(acme_app_avatar_url(ri: "jp", host: @app_host), headers: headers, title: "Avatar")
    assert_self_service_page(acme_app_identity_url(ri: "jp", host: @app_host), headers: headers, title: "Identity")
    assert_self_service_page(
      acme_app_current_organization_url(ri: "jp", host: @app_host), headers: headers,
                                                                    title: "Organization",
    )
    assert_self_service_page(
      edit_acme_app_current_organization_path(ri: "jp", host: @app_host), headers: headers,
                                                                          title: "Organization",
    )
    assert_self_service_page(acme_app_account_url(ri: "jp", host: @app_host), headers: headers, title: "Account")
    assert_self_service_page(edit_acme_app_account_path(ri: "jp", host: @app_host), headers: headers, title: "Account")

    post acme_app_organizations_url(ri: "jp", host: @app_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)

    patch acme_app_account_url(ri: "jp", host: @app_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)

    patch acme_app_current_organization_url(ri: "jp", host: @app_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)

    patch acme_app_avatar_url(ri: "jp", host: @app_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)

    delete acme_app_avatar_url(ri: "jp", host: @app_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)
  end

  test "org self service pages require authentication" do
    assert_requires_authentication(acme_org_avatar_url(ri: "jp", host: @org_host), host: @org_host)
    assert_requires_authentication(acme_org_identity_url(ri: "jp", host: @org_host), host: @org_host)
    assert_requires_authentication(acme_org_current_organization_url(ri: "jp", host: @org_host), host: @org_host)
    assert_requires_authentication(acme_org_account_url(ri: "jp", host: @org_host), host: @org_host)
  end

  test "org self service pages render for signed in operator" do
    operator = operators(:one)
    token = OperatorToken.create!(staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: operator, token: token)
    headers = as_staff_headers(operator, host: @org_host, session_public_id: token.public_id)

    assert_self_service_page(acme_org_avatar_url(ri: "jp", host: @org_host), headers: headers, title: "Avatar")
    assert_self_service_page(acme_org_identity_url(ri: "jp", host: @org_host), headers: headers, title: "Identity")
    assert_self_service_page(
      acme_org_current_organization_url(ri: "jp", host: @org_host), headers: headers,
                                                                    title: "Organization",
    )
    assert_self_service_page(
      edit_acme_org_current_organization_path(ri: "jp", host: @org_host), headers: headers,
                                                                          title: "Organization",
    )
    assert_self_service_page(acme_org_account_url(ri: "jp", host: @org_host), headers: headers, title: "Account")
    assert_self_service_page(edit_acme_org_account_path(ri: "jp", host: @org_host), headers: headers, title: "Account")

    post acme_org_organizations_url(ri: "jp", host: @org_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)

    patch acme_org_account_url(ri: "jp", host: @org_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)

    patch acme_org_current_organization_url(ri: "jp", host: @org_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)

    patch acme_org_avatar_url(ri: "jp", host: @org_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)

    delete acme_org_avatar_url(ri: "jp", host: @org_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)
  end

  test "com self service pages require authentication" do
    assert_requires_authentication(acme_com_identity_url(ri: "jp", host: @com_host), host: @com_host)
    assert_requires_authentication(acme_com_account_url(ri: "jp", host: @com_host), host: @com_host)
  end

  test "com self service pages render for signed in visitor" do
    visitor = create_verified_visitor_with_email(email_address: "acme-self-service-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    select_token!(surface: :com, principal: visitor, token: token)
    headers = as_visitor_headers(visitor, host: @com_host, session_public_id: token.public_id)

    assert_self_service_page(acme_com_identity_url(ri: "jp", host: @com_host), headers: headers, title: "Identity")
    assert_self_service_page(acme_com_account_url(ri: "jp", host: @com_host), headers: headers, title: "Account")
    assert_self_service_page(edit_acme_com_account_path(ri: "jp", host: @com_host), headers: headers, title: "Account")

    patch acme_com_account_url(ri: "jp", host: @com_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)

    patch acme_com_current_organization_url(ri: "jp", host: @com_host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)
  end

  test "com does not expose avatar or organization self service routes" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{@com_host}/avatar", method: :get)
    end
  end

  private

  def select_token!(surface:, principal:, token:)
    AcmeSelectorBootstrapAuthority.call(surface: surface, principal: principal)
    AcmeSelectorAuthority.prepare(surface: surface, principal: principal, session: token)
  end

  def assert_requires_authentication(url, host:)
    get(url, headers: host_headers(host))

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)
  end

  def assert_self_service_page(url, headers:, title:)
    get(url, headers: headers)

    assert_response :success
    assert_select "h1", title
    assert_includes response.body, "Signed in"
    assert_no_match(/id\.umaxica/, response.body)
  end
end
