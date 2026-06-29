# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class JumpGatewayBoundaryInvariantTest < ActiveSupport::TestCase
  test "application routes do not expose the external jump gateway" do
    route_names = Rails.application.routes.named_routes.helper_names.grep(/\Ajump_/)

    assert_empty route_names
  end

  test "legacy DB backed jump links are not part of the app boundary" do
    assert_not Object.const_defined?(:AppJumpLink)
    assert_not Object.const_defined?(:ComJumpLink)
    assert_not Object.const_defined?(:OrgJumpLink)
    assert_not Object.const_defined?(:JumpLinkable)
  end
end
