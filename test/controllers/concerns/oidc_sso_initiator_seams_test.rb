# typed: false
# frozen_string_literal: true

require "test_helper"

# OidcSsoInitiator decides, per request, whether the authorization URL may be
# followed directly, has to go through the jump page, or must be refused. The
# refusal arm and the surface labelling that goes with it into the log had no
# coverage, so a redirect policy that stopped refusing anything would still pass.
class OidcSsoInitiatorSeamsTest < ActiveSupport::TestCase
  ACME_ORIGIN = "https://www.umaxica.app"

  def build_context(class_name: "Base::App::OidcTestController", host: "www.umaxica.app")
    # rubocop:disable Rails/ApplicationController -- the concern under test must be
    # exercised without the surface stack ApplicationController drags in.
    klass = Class.new(ActionController::Base) { include ::OidcSsoInitiator }
    # rubocop:enable Rails/ApplicationController
    klass.define_singleton_method(:name) { class_name }
    request = ActionDispatch::TestRequest.create
    request.host = host
    context = klass.new
    context.set_request!(request)
    context.set_response!(klass.make_response!(request))
    context.define_singleton_method(:oidc_base_authority_host) { ACME_ORIGIN }
    context.define_singleton_method(:oidc_base_service_origin) do
      Oidc::AcmeServiceOrigin.from(ACME_ORIGIN, default_scheme: "https")
    end
    context.define_singleton_method(:oidc_client_id) { "test-client" }
    context
  end

  test "an authorization URL that cannot be parsed is refused rather than followed" do
    context = build_context

    context.send(:redirect_to_oidc_authorization_url, "http://[oops")

    assert_equal 400, context.response.status
    assert_not context.send(:same_site_oidc_authorization_url?, "http://[oops")
    assert_equal "invalid_url", context.send(:same_site_oidc_rejection_reason, "http://[oops")
  end

  test "a return target that is not valid base64 falls back to the site root" do
    context = build_context

    assert_equal "/", context.send(:decode_pt, "%%%not-base64%%%")
    assert_equal "/settings", Base64.urlsafe_decode64(context.send(:encoded_pt, "/settings"))
  end

  test "a non-localhost authority is addressed over https regardless of the request scheme" do
    context = build_context

    assert_equal "https", context.send(:oidc_base_default_scheme)
    assert_equal "https", context.send(:oidc_acme_default_scheme)
  end

  test "a localhost authority follows the request scheme so development is not forced to https" do
    context = build_context(host: "base.app.localhost")
    context.define_singleton_method(:oidc_base_authority_host) { "base.app.localhost" }

    assert_equal "http", context.send(:oidc_base_default_scheme)
  end

  # The label decides which surface a redirect refusal is attributed to in the log.
  {
    "Sign::App::SessionsController" => "sign_app",
    "Sign::Com::SessionsController" => "sign_com",
    "Sign::Org::SessionsController" => "sign_org",
    "Core::App::SessionsController" => "core_app",
    "Base::Org::SessionsController" => "base_org",
    "Palm::App::SessionsController" => "palm_app",
    "Unnamespaced::SessionsController" => "Unnamespaced::SessionsController",
  }.each do |class_name, expected_surface|
    test "#{class_name} reports itself as #{expected_surface}" do
      context = build_context(class_name: class_name)

      assert_equal expected_surface, context.send(:oidc_redirect_surface)
    end
  end

  test "an unparsable token endpoint is answered as configured rather than rewritten" do
    context = build_context

    assert_equal "http://[oops", context.send(:local_oidc_token_endpoint, "http://[oops")
  end
end
