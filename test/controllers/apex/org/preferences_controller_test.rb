# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Org::PreferencesControllerTest < ActiveSupport::TestCase
  test "show does not raise" do
    controller = Apex::Org::PreferencesController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new

    assert_nothing_raised do
      controller.show
    end
  end
end
