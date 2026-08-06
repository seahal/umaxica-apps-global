# typed: false
# frozen_string_literal: true

require "test_helper"

# Both account-recovery entry points shipped with structurally broken ERB and
# returned 500, because no request test exercised either route. Account recovery
# is the fallback path when a user is locked out, so a 500 here pushes people to
# support-channel identity proofing instead.
#
# Full template coverage lives in test/unit/views/template_compilation_test.rb,
# which compiles all templates. These tests pin the routes themselves.
class IdentityRecoveryEntrypointRenderTest < ActionDispatch::IntegrationTest
  test "com recovery session entry point renders" do
    get "http://base.com.localhost/identity/recovery/session/new?ri=jp"

    assert_response :success
    assert_match "Account recovery", response.body
  end

  test "app recovery session entry point renders" do
    get "http://base.app.localhost/identity/recovery/session/new?ri=jp"

    assert_response :success
    assert_match "Account recovery", response.body
  end

  test "app recovery status page redirects to the entry point without a ceremony" do
    # Base::App::Identity::RecoveriesController#show is :open but requires a
    # recovery ceremony cookie. Without one it must redirect, not error.
    get "http://base.app.localhost/identity/recovery?ri=jp"

    assert_response :see_other
    assert_match "/identity/recovery/session/new", response.location
  end

  test "com recovery status page redirects to the entry point without a ceremony" do
    get "http://base.com.localhost/identity/recovery?ri=jp"

    assert_response :see_other
    assert_match "/identity/recovery/session/new", response.location
  end
end
