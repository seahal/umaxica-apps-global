# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceBindingMethodVisitorTokenTest < ActiveSupport::TestCase
  class VisitorTokenProbe
    include PreferenceBase

    def controller_path
      "base/com/preferences"
    end

    def preference_class
      VisitorToken
    end

    def binding_method_class
      send(:preference_binding_method_class)
    end

    def dbsc_status_class
      send(:preference_dbsc_status_class)
    end
  end

  test "VisitorToken has a binding-method class registered like ClientToken/OperatorToken" do
    assert_equal VisitorTokenBindingMethod, VisitorTokenProbe.new.binding_method_class
  end

  test "VisitorToken has a DBSC status class registered like ClientToken/OperatorToken" do
    assert_equal VisitorTokenDbscStatus, VisitorTokenProbe.new.dbsc_status_class
  end
end
