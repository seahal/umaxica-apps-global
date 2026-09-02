# typed: false
# frozen_string_literal: true

require "test_helper"

# Palm logout must fail closed when the access token cannot be authenticated or
# the matching client token is missing or inactive. Success is covered by the
# Palm logout request tests; these are the refusal branches.
class PalmLogoutCoordinatorFailureTest < ActiveSupport::TestCase
  test "returns the authenticator error when the access token is rejected" do
    request = ActionDispatch::TestRequest.create
    request.headers["Authorization"] = "Bearer rejected"
    auth = Struct.new(:success?, :error, :payload, :resource).new(false, "invalid_token", nil, nil)

    PalmAccessTokenAuthenticator.stub(:call, auth) do
      result = PalmLogoutCoordinator.call(request: request, ri: "jp")

      assert_not result.success?
      assert_equal "invalid_token", result.error
      assert_equal "authentication failed", result.error_description
    end
  end

  test "returns invalid_token when no client token matches the access-token claims" do
    request = ActionDispatch::TestRequest.create
    request.headers["Authorization"] = "Bearer missing"
    auth = Struct.new(:success?, :error, :payload, :resource).new(
      true, nil, { "sid" => "sid", "jti" => "jti", "client_id" => "app" }, Object.new,
    )

    PalmAccessTokenAuthenticator.stub(:call, auth) do
      ClientToken.stub(:find_by, nil) do
        result = PalmLogoutCoordinator.call(request: request, ri: "jp")

        assert_not result.success?
        assert_equal "invalid_token", result.error
        assert_equal "logout token not found", result.error_description
      end
    end
  end

  test "returns invalid_token when the matching client token is no longer active" do
    request = ActionDispatch::TestRequest.create
    request.headers["Authorization"] = "Bearer inactive"
    token = Object.new
    token.define_singleton_method(:active?) { false }
    auth = Struct.new(:success?, :error, :payload, :resource).new(
      true, nil, { "sid" => "sid", "jti" => "jti" }, Object.new,
    )

    PalmAccessTokenAuthenticator.stub(:call, auth) do
      ClientToken.stub(:find_by, token) do
        result = PalmLogoutCoordinator.call(request: request, ri: "jp")

        assert_not result.success?
        assert_equal "logout token is not active", result.error_description
      end
    end
  end
end
