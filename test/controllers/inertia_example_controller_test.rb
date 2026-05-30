# typed: false
# frozen_string_literal: true

require "test_helper"

class InertiaExampleControllerTest < ActionDispatch::IntegrationTest
  test "controller class is loadable" do
    assert_kind_of Class, InertiaExampleController
  end
end
