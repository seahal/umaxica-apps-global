# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module App
    class AuthorityRedirectHarness
      include SignAuthorityRedirect

      attr_accessor :request, :params_hash, :redirect_args

      def initialize(request:, params_hash: {})
        @request = request
        @params_hash = params_hash
      end

      def params = ActionController::Parameters.new(@params_hash)

      def redirect_to(*args, **kwargs)
        @redirect_args = [args, kwargs]
      end

      def cross_host_redirect_allowed?
        true
      end
    end
  end

  module Com
    class AuthorityRedirectHarness < Sign::App::AuthorityRedirectHarness
    end
  end

  module Org
    class AuthorityRedirectHarness < Sign::App::AuthorityRedirectHarness
    end
  end
end

class OtherSurfaceAuthorityRedirectHarness
  include SignAuthorityRedirect

  attr_accessor :request, :params_hash, :redirect_args

  def initialize(request:, params_hash: {})
    @request = request
    @params_hash = params_hash
  end

  def params = ActionController::Parameters.new(@params_hash)

  def redirect_to(*args, **kwargs)
    @redirect_args = [args, kwargs]
  end

  def cross_host_redirect_allowed?
    false
  end
end

class SignAuthorityRedirectTest < ActiveSupport::TestCase
  test "redirect_to_sign_authority! builds a sign-app host URL and forwards query params" do
    request = Struct.new(:scheme, :host).new("https", "app.example.test")
    harness = Sign::App::AuthorityRedirectHarness.new(
      request: request,
      params_hash: { extra: "ignored" },
    )

    harness.send(:redirect_to_sign_authority!, "/sign-in", query: { ri: "tokyo" })

    location, options = harness.redirect_args
    uri = URI.parse(location.first)

    assert_equal "https", uri.scheme
    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), uri.host
    assert_equal "/sign-in", uri.path
    assert_equal "ri=tokyo", uri.query
    assert options[:allow_other_host]
    assert_equal :see_other, options[:status]
  end

  test "redirect_to_base_authority! uses the com and org base hosts" do
    request = Struct.new(:scheme, :host).new("https", "com.example.test")
    com = Sign::Com::AuthorityRedirectHarness.new(request: request)
    org = Sign::Org::AuthorityRedirectHarness.new(request: request)

    com.send(:redirect_to_base_authority!, "/home")
    org.send(:redirect_to_acme_authority!, "/home")

    com_uri = URI.parse(com.redirect_args.first.first)
    org_uri = URI.parse(org.redirect_args.first.first)

    assert_equal ENV.fetch("PRIVATE_BASE_CORPORATE_URL"), com_uri.host
    assert_equal ENV.fetch("PRIVATE_BASE_STAFF_URL"), org_uri.host
    assert_equal request.host, OtherSurfaceAuthorityRedirectHarness.new(request: request).send(:base_authority_host)
    assert_equal request.host, OtherSurfaceAuthorityRedirectHarness.new(request: request).send(:sign_authority_host)
    assert_equal request.host, OtherSurfaceAuthorityRedirectHarness.new(request: request).send(:acme_authority_host)
  end

  test "sign_authority_query copies an explicit query or falls back to the ri param" do
    request = Struct.new(:scheme, :host).new("https", "app.example.test")
    with_ri = Sign::App::AuthorityRedirectHarness.new(request: request, params_hash: { ri: "osaka" })
    blank = Sign::App::AuthorityRedirectHarness.new(request: request, params_hash: { ri: "" })

    assert_equal "a=1", with_ri.send(:sign_authority_query, { a: 1 })
    assert_equal "ri=osaka", with_ri.send(:sign_authority_query)
    assert_nil blank.send(:sign_authority_query)
  end

  test "sign_authority_host maps Sign App Com and Org class names" do
    request = Struct.new(:scheme, :host).new("https", "ignored.example.test")

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                 Sign::App::AuthorityRedirectHarness.new(request: request).send(:sign_authority_host)
    assert_equal ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"),
                 Sign::Com::AuthorityRedirectHarness.new(request: request).send(:sign_authority_host)
    assert_equal ENV.fetch("PRIVATE_AUTH_STAFF_URL"),
                 Sign::Org::AuthorityRedirectHarness.new(request: request).send(:sign_authority_host)
    assert_equal ENV.fetch("PRIVATE_BASE_SERVICE_URL"),
                 Sign::App::AuthorityRedirectHarness.new(request: request).send(:base_authority_host)
  end
end
