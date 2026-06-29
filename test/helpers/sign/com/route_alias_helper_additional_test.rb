# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignComRouteAliasHelperTest < ActiveSupport::TestCase
  test "including into a class defines app aliases as instance methods" do
    controller_class =
      Class.new do
        include SignComRouteAliasHelper
      end

    assert_not_respond_to controller_class.new, :sign_com_root_path
  end

  test "extending a module defines aliases usable by including classes" do
    mod = Module.new
    mod.extend(SignComRouteAliasHelper)

    consumer = Class.new { include mod }

    assert_not_respond_to consumer.new, :sign_com_root_path
  end

  test "extending an object defines aliases on its singleton class" do
    object = Object.new
    object.extend(SignComRouteAliasHelper)

    assert_not_respond_to object, :sign_com_root_path
  end
end

# DAMP local route helper aliases for former shared test support.
class SignComRouteAliasHelperTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
