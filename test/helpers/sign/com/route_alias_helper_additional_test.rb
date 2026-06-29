# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

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
