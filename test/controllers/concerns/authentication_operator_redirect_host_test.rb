# typed: false
# frozen_string_literal: true

require "test_helper"

# An unauthenticated staff request is sent to the staff sign-in host. Which host
# that is depends on the host the request arrived on: a request already on the
# configured staff host stays there, and anything else is sent to the configured
# host rather than being bounced back to whatever host asked. Sending a staff
# sign-in to an arbitrary request host is an open redirect on the staff surface.
class AuthenticationOperatorRedirectHostTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # The concern declares callbacks when included, so the harness has to be a
  # controller. ApplicationController would drag in the surface stack this is
  # deliberately outside of.
  class Harness < ActionController::Base # rubocop:disable Rails/ApplicationController
    include ::AuthenticationOperator

    def invoke(name, ...) = send(name, ...)
  end

  def build_harness(host:)
    request = ActionDispatch::TestRequest.create
    request.host = host
    harness = Harness.new
    harness.set_request!(request)
    harness.set_response!(Harness.make_response!(request))
    harness
  end

  test "a request already on the staff host keeps that host" do
    staff_host = CommonRedirect.normalize_host(ENV.fetch("PRIVATE_AUTH_STAFF_URL"))

    assert_equal staff_host, build_harness(host: staff_host).invoke(:sign_org_redirect_host)
  end

  test "a request from any other host is sent to the configured staff host" do
    harness = build_harness(host: "attacker.example.com")

    assert_equal CommonRedirect.normalize_host(ENV.fetch("PRIVATE_AUTH_STAFF_URL")),
                 harness.invoke(:sign_org_redirect_host)
  end

  test "the staff sign-in URL is always https on the resolved staff host" do
    url = build_harness(host: "attacker.example.com").invoke(:sign_in_url_with_pt, "/settings")

    assert_match(%r{\Ahttps://}, url)
    assert_includes url, CommonRedirect.normalize_host(ENV.fetch("PRIVATE_AUTH_STAFF_URL"))
    assert_not_includes url, "attacker.example.com"
  end

  test "an operator is only active when one is present and their record says so" do
    harness = build_harness(host: "attacker.example.com")

    harness.define_singleton_method(:current_resource) { nil }

    assert_not harness.invoke(:active_operator?)

    harness.define_singleton_method(:current_resource) { Struct.new(:active?).new(false) }

    assert_not harness.invoke(:active_operator?)

    harness.define_singleton_method(:current_resource) { Struct.new(:active?).new(true) }

    assert harness.invoke(:active_operator?)
  end

  test "the staff surface names its own models and never another surface's" do
    harness = build_harness(host: "attacker.example.com")

    assert_equal ::Operator, harness.invoke(:resource_class)
    assert_equal OperatorToken, harness.invoke(:token_class)
    assert_equal ::OperatorChronicle, harness.invoke(:audit_class)
    assert_equal "operator", harness.invoke(:resource_type)
    assert_equal :staff_id, harness.invoke(:resource_foreign_key)
    assert_predicate harness, :am_i_operator?
    assert_not harness.am_i_user?
    assert_not harness.am_i_owner?
  end

  test "a failed staff login is audited against the operator that was attempted" do
    harness = build_harness(host: "attacker.example.com")
    recorded = []
    harness.define_singleton_method(:record_audit) { |event, **kwargs| recorded << [event, kwargs] }
    operator = Struct.new(:id).new(7)

    harness.audit_operator_login_failed(nil)

    assert_empty recorded, "there is nothing to audit when no operator was resolved"

    harness.audit_operator_login_failed(operator)

    assert_equal 1, recorded.size
    assert_equal AuthenticationOperator::AUDIT_EVENTS[:login_failed], recorded.first.first
    assert_equal operator, recorded.first.last.fetch(:resource)
    assert_nil recorded.first.last.fetch(:actor)
  end
end
