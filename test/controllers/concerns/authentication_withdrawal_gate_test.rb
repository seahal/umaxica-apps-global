# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit test for AuthenticationWithdrawalGate#withdrawal_gate_redirect_path.
#
# This pins the cross-surface safety contract: the withdrawal redirect target is
# derived from the controller_path surface family (app/com/org), and an unknown
# family must raise instead of silently falling back to an app-surface path.
# A regression here (e.g. an org request redirected to the app withdrawal page,
# or a rescued default masking a routing bug) would leak an actor across surfaces.
class AuthenticationWithdrawalGateTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  self.fixture_table_names = []

  # Minimal host that includes only the gate plus the route helpers it calls.
  class Host
    include Rails.application.routes.url_helpers
    include AuthenticationWithdrawalGate

    attr_accessor :controller_path_value

    def initialize(controller_path)
      @controller_path_value = controller_path
    end

    def controller_path
      @controller_path_value
    end

    def params
      { AuthIoKeys::Params::RI => "jp" }
    end

    # Expose the private methods under test.
    public :withdrawal_gate_redirect_path, :withdrawal_gate_surface_family,
           :withdrawal_restricted_resource?
  end

  test "app family controllers redirect to the app withdrawal edit path" do
    %w(auth/app/sign/ins base/app/identity/sessions core/app/home side/app/home).each do |path|
      host = Host.new(path)

      assert_equal "app", host.withdrawal_gate_surface_family, path
      assert_equal edit_base_app_identity_withdrawal_path(ri: "jp"),
                   host.withdrawal_gate_redirect_path, path
    end
  end

  test "com family controllers redirect to the com withdrawal edit path" do
    %w(auth/com/sign/ins base/com/identity/sessions core/com/home side/com/home).each do |path|
      host = Host.new(path)

      assert_equal "com", host.withdrawal_gate_surface_family, path
      assert_equal edit_base_com_identity_withdrawal_path(ri: "jp"),
                   host.withdrawal_gate_redirect_path, path
    end
  end

  test "org family controllers redirect to the org withdrawal path, never the app path" do
    %w(auth/org/sign/ins base/org/identity/sessions core/org/home side/org/home).each do |path|
      host = Host.new(path)

      assert_equal "org", host.withdrawal_gate_surface_family, path
      assert_equal base_org_identity_withdrawal_path(ri: "jp"),
                   host.withdrawal_gate_redirect_path, path
      assert_not_equal edit_base_app_identity_withdrawal_path(ri: "jp"),
                       host.withdrawal_gate_redirect_path, path
    end
  end

  test "an unknown surface family raises instead of silently redirecting to the app surface" do
    host = Host.new("rails/health")

    error = assert_raises(ArgumentError) { host.withdrawal_gate_redirect_path }
    assert_match(/rails\/health/, error.message)
  end

  test "withdrawal restricted resource covers every withdrawal lifecycle state" do
    host = Host.new("base/app/identity/sessions")

    closing = withdrawal_double(closing: true)
    suspended = withdrawal_double(suspended: true)
    terminated = withdrawal_double(terminated: true)
    deactivated = withdrawal_double(deactivated: true)
    active = withdrawal_double

    assert host.withdrawal_restricted_resource?(closing), "closing must be restricted"
    assert host.withdrawal_restricted_resource?(suspended), "suspended must be restricted"
    assert host.withdrawal_restricted_resource?(terminated), "terminated must be restricted"
    assert host.withdrawal_restricted_resource?(deactivated), "deactivated must be restricted"
    assert_not host.withdrawal_restricted_resource?(active), "active must not be restricted"
  end

  private

  def withdrawal_double(closing: false, suspended: false, terminated: false, deactivated: false)
    Struct.new(:closing?, :suspended?, :terminated?, :deactivated?)
      .new(closing, suspended, terminated, deactivated)
  end
end
