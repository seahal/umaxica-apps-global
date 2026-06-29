# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceSignScreenActionsTest < ActiveSupport::TestCase
  class ExplicitActionHarness < ApplicationController
    include PreferenceSignScreenActions

    before_action :ensure_preferences_record

    def edit
      edit_theme_preference_screen
    end

    def update
      update_theme_preference_screen
    end
  end

  # Minimal harness for testing update_region_preference_screen without a real
  # request cycle. Stubs DB writes and URL helpers so the redirect params can be
  # inspected directly.
  class RegionUpdateHarness
    class << self
      def before_action(*) = nil

      def helper_method(*) = nil
    end

    include PreferenceCore
    include PreferenceSignScreenActions

    attr_accessor :params_hash, :last_redirect_url, :last_redirect_params

    def initialize
      @params_hash = {}
    end

    def params = ActionController::Parameters.new(params_hash)

    def get_region = "jp"

    def preference_edit_url(_screen, redirect_params)
      @last_redirect_params = redirect_params
      "/preference/region/edit"
    end

    def redirect_to(url, **) = @last_redirect_url = url

    def preference_update_notice = nil

    # Stub out DB-touching methods so unit tests do not need fixtures.
    def set_region_preferences_update = nil

    def ensure_preference_access_token_audience_for_write! = nil
  end

  test "including sign screen actions does not expose a controller DSL" do
    assert_not_respond_to ExplicitActionHarness, :preference_screen
  end

  test "controller exposes explicit public actions" do
    assert_includes ExplicitActionHarness.public_instance_methods, :edit
    assert_includes ExplicitActionHarness.public_instance_methods, :update
  end

  test "update_region_preference_screen redirect does not carry the ri query parameter" do
    # Regression: before the fix, ri=us in the request URL survived into the
    # redirect so the newly-saved JWT region was never reflected in the URL.
    controller = RegionUpdateHarness.new
    controller.params_hash = { ri: "us", lx: "en" }

    controller.send(:update_region_preference_screen)

    assert_nil controller.last_redirect_params[:ri],
               "ri must be absent from the redirect so set_region re-derives it from the JWT"
    assert_equal "en", controller.last_redirect_params[:lx]
  end
end
