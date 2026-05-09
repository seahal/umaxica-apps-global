# typed: false
# frozen_string_literal: true

require "test_helper"

class ApexConfigurationEmailsControllerTest < ActiveSupport::TestCase
  [
    Apex::App::Configuration::EmailsController,
    Apex::Org::Configuration::EmailsController,
  ].each do |klass|
    test "#{klass.name} sets defaults and responds ok for mutations" do
      controller = klass.new
      controller.define_singleton_method(:params) { ActionController::Parameters.new({ ct: "jp", lx: "en", tz: "Etc/UTC" }) }
      controller.define_singleton_method(:head) { |status| @_test_head = status }

      controller.send(:set_defaults)

      assert_equal "JP", controller.instance_variable_get(:@current_region)
      assert_equal "EN", controller.instance_variable_get(:@current_language)
      assert_equal "Etc/UTC", controller.instance_variable_get(:@current_timezone)

      controller.create

      assert_equal :ok, controller.instance_variable_get(:@_test_head)

      controller.update

      assert_equal :ok, controller.instance_variable_get(:@_test_head)
    end
  end
end
