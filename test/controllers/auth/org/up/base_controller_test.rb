# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::Sign::Up::BaseControllerTest < ActionDispatch::IntegrationTest
  test "after_login_path returns base org identity URL" do
    controller = Auth::Org::Sign::Up::BaseController.new

    controller.define_singleton_method(:current_region_identifier) { "jp" }
    controller.define_singleton_method(:base_authority_host) { "www.umaxica.org" }
    controller.define_singleton_method(:base_org_identity_url) do |ri:, host:|
      "https://#{host}/identity?ri=#{ri}"
    end

    assert_equal "https://www.umaxica.org/identity?ri=jp", controller.send(:after_login_path)
  end

  test "after_login_path raises route errors instead of hiding them" do
    controller = Auth::Org::Sign::Up::BaseController.new

    controller.define_singleton_method(:current_region_identifier) { "jp" }
    controller.define_singleton_method(:base_authority_host) { "www.umaxica.org" }
    controller.define_singleton_method(:base_org_identity_url) { |**| raise StandardError, "route missing" }

    error =
      assert_raises(StandardError) do
        controller.send(:after_login_path)
      end

    assert_equal "route missing", error.message
  end
end
