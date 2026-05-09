# typed: false
# frozen_string_literal: true

require "test_helper"

class Authentication::ViewerCoverageTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Authentication::Viewer

    attr_accessor :rendered_json, :redirected_to, :alert_message

    def render(json:, status:)
      @rendered_json = { json: json, status: status }
    end

    def redirect_to(path, alert:)
      @redirected_to = path
      @alert_message = alert
    end
  end

  setup do
    @harness = Harness.new
    @harness.request = ActionDispatch::TestRequest.create
  end

  test "audit_viewer_login_failed returns nil" do
    assert_nil @harness.audit_viewer_login_failed(Object.new)
  end

  test "active_viewer? returns false" do
    assert_not @harness.active_viewer?
  end

  test "am_i_user? returns false" do
    assert_not @harness.am_i_user?
  end

  test "am_i_staff? returns false" do
    assert_not @harness.am_i_staff?
  end

  test "am_i_owner? returns false" do
    assert_not @harness.am_i_owner?
  end

  test "transparent_refresh_access_token returns nil" do
    assert_nil @harness.transparent_refresh_access_token
  end

  test "authenticate! renders json for json request" do
    @harness.request.format = :json
    @harness.authenticate!

    assert_equal({ error: "Unauthorized" }, @harness.rendered_json[:json])
    assert_equal :unauthorized, @harness.rendered_json[:status]
  end

  test "authenticate! redirects for html request" do
    @harness.request.format = :html
    @harness.authenticate!

    assert_equal "/", @harness.redirected_to
    assert_equal I18n.t("auth.unauthorized"), @harness.alert_message
  end

  test "private methods" do
    assert_equal Object, @harness.send(:resource_class)
    assert_equal Object, @harness.send(:token_class)
    assert_equal Object, @harness.send(:audit_class)
    assert_equal "viewer", @harness.send(:resource_type)
    assert_equal :viewer_id, @harness.send(:resource_foreign_key)
    assert_equal "X-TEST-CURRENT-VIEWER", @harness.send(:test_header_key)
    assert_equal "/", @harness.send(:sign_in_url_with_return, "/any")
  end
end
