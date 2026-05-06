# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceGlobalTestController < ApplicationController
  def set_color_theme
  end

  def set_preferences_cookie
  end

  def set_locale_from_params
  end

  def set_timezone_from_session
  end

  def preference_payload_value(_)
    nil
  end

  def write_preference_cookie(_, _)
  end

  include Preference::Global

  def index
    render plain: "ok"
  end
end

class Preference::GlobalTest < ActiveSupport::TestCase
  test "requested_context normalizes params and ignores invalid ri" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(ri: "US", lx: "EN", ct: "DR", tz: "UTC", bad: "value")

    context = controller.requested_context

    assert_equal({ ri: "us", lx: "en", ct: "dr", tz: "utc" }, context)
  end

  test "default_url_options merges requested context" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(ri: "us", lx: "EN", ct: "DR", tz: "UTC")

    assert_equal({ ri: "us", lx: "en", ct: "dr", tz: "utc" }, controller.default_url_options)
  end

  test "ensure_required_ri! redirects when required ri differs" do
    controller = PreferenceGlobalTestController.new
    controller.request = ActionDispatch::TestRequest.create(
      "HTTP_HOST" => "example.com", "PATH_INFO" => "/prefs",
      "QUERY_STRING" => "lx=en",
    )
    controller.response = ActionDispatch::TestResponse.new
    controller.params = ActionController::Parameters.new(ri: "jp", lx: "en")
    controller.define_singleton_method(:required_ri) { "us" }
    controller.define_singleton_method(:performed?) { false }
    controller.define_singleton_method(:redirect_to) do |url, allow_other_host:, status:|
      @redirect_args = [url, allow_other_host, status].freeze
    end

    controller.ensure_required_ri!

    assert_equal ["http://example.com/prefs?lx=en&ri=us", false, :found],
                 controller.instance_variable_get(:@redirect_args)
  end
end
