# typed: false
# frozen_string_literal: true

require "test_helper"

class DbscRegistrationEndpointWiringTest < ActiveSupport::TestCase
  test "sign dbsc controllers use shared registration endpoint concern" do
    assert_includes Sign::App::Edge::V0::Token::DbscController, SignDbscRegistrationEndpoint
    assert_includes Sign::Org::Edge::V0::Token::DbscController, SignDbscRegistrationEndpoint
  end

  test "acme dbsc controllers use shared preference registration endpoint concern" do
    assert_includes Base::App::Edge::V0::DbscController, PreferenceDbscRegistrationEndpoint
    assert_includes Base::Org::Edge::V0::DbscController, PreferenceDbscRegistrationEndpoint
    assert_includes Base::Com::Edge::V0::DbscController, PreferenceDbscRegistrationEndpoint
  end

  test "controllers do not redefine dbsc registration internals locally" do
    sign_controllers = [
      Sign::App::Edge::V0::Token::DbscController,
      Sign::Org::Edge::V0::Token::DbscController,
    ]
    acme_controllers = [
      Base::App::Edge::V0::DbscController,
      Base::Org::Edge::V0::DbscController,
      Base::Com::Edge::V0::DbscController,
    ]

    (sign_controllers + acme_controllers).each do |controller|
      assert_not_includes controller.instance_methods(false), :handle_registration
      assert_not_includes controller.instance_methods(false), :handle_bound_cookie_refresh
      assert_not_includes controller.instance_methods(false), :dbsc_cookie_attributes_string
    end
  end
end
