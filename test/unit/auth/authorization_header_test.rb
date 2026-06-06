# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAuthorizationHeaderTest < ActiveSupport::TestCase
  RequestStub = Struct.new(:authorization, :headers)

  test "scheme reads the authorization scheme from the request header" do
    request = RequestStub.new("Bearer abc123", {})

    assert_equal "Bearer", AuthAuthorizationHeader.scheme(request)
  end

  test "access_token returns bearer token when present" do
    request = RequestStub.new("Bearer abc123", {})

    assert_equal "abc123", AuthAuthorizationHeader.access_token(request)
  end

  test "access_token returns dpop token when bearer token is absent" do
    request = RequestStub.new("DPoP xyz789", {})

    assert_equal "xyz789", AuthAuthorizationHeader.access_token(request)
  end

  test "token_and_options parses token and options" do
    request = RequestStub.new("Bearer abc123, kid=one, alg=ES256", {})

    token, options = AuthAuthorizationHeader.token_and_options(request)

    assert_equal "abc123", token
    assert_equal({ "kid" => "one", "alg" => "ES256" }, options)
  end

  test "scheme returns nil when no authorization header is present" do
    request = RequestStub.new(nil, {})

    assert_nil AuthAuthorizationHeader.scheme(request)
  end
end
