# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceRegionalTestController < ApplicationController
  # Mock methods required by Preference::Base
  def set_color_theme
  end

  def set_preferences_cookie
  end

  def set_locale_from_params
  end

  def set_timezone_from_session
  end

  def preference_payload_value(_); nil; end

  def write_preference_cookie(_, _)
  end

  include Preference::Regional

  def index
    render plain: "ok"
  end
end

class Preference::RegionalTest < ActionDispatch::IntegrationTest
  setup do
    Rails.application.routes.draw do
      get "/regional_test", to: "preference_regional_test#index"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "canonicalize_regional_params strips 'ri' and redirects" do
    get "/regional_test?ri=jp&lx=en"

    assert_response :moved_permanently
    assert_redirected_to "http://www.example.com/regional_test?lx=en"
  end

  test "canonicalize_regional_params strips 'ri' when only 'ri' is present" do
    get "/regional_test?ri=jp"

    assert_response :moved_permanently
    assert_redirected_to "http://www.example.com/regional_test"
  end

  test "does not redirect if 'ri' is absent" do
    get "/regional_test?lx=en"

    assert_response :success
    assert_equal "ok", response.body
  end

  test "helper methods return expected defaults" do
    controller = PreferenceRegionalTestController.new

    assert_equal "sy", controller.send(:get_theme)
    assert_equal "ja", controller.send(:get_language)
    assert_equal "jp", controller.send(:get_region)
    assert_equal "ASIA/Tokyo", controller.send(:get_timezone)
  end

  test "default_url_options returns empty when no context" do
    controller = PreferenceRegionalTestController.new
    controller.request = ActionDispatch::Request.new({})
    controller.params = {}

    assert_equal({}, controller.default_url_options)
  end

  test "default_url_options includes lx, tz, ct when all are present" do
    controller = PreferenceRegionalTestController.new
    controller.request = ActionDispatch::Request.new({})
    controller.params = ActionController::Parameters.new(lx: "EN", tz: "UTC", ct: "DR")

    options = controller.default_url_options

    assert_equal "en", options[:lx]
    assert_equal "utc", options[:tz]
    assert_equal "dr", options[:ct]
  end

  test "set_timezone and set_locale do not raise errors" do
    # Simply hitting the endpoint triggers before_actions
    get "/regional_test"

    assert_response :success
  end
end
