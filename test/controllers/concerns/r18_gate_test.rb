# typed: false
# frozen_string_literal: true

require "test_helper"

class R18GateTestController < ApplicationController
  include R18Gate

  class_attribute :r18_required_actions, default: Set.new # rubocop:disable ThreadSafety/ClassAndModuleAttributes
  before_action :require_r18_viewing!
  r18_required :show, :create

  class << self
    attr_accessor :test_actor # rubocop:disable ThreadSafety/ClassAndModuleAttributes
  end

  def show
    render plain: "r18 content"
  end

  def create
    render plain: "mutated"
  end

  def gate
    set_r18_no_store!
    render plain: "gate"
  end

  def acknowledge
    acknowledge_r18!
    redirect_to(r18_safe_pt(params[:pt]), allow_other_host: false)
  end

  def blocked
    render plain: "blocked"
  end

  def stopped
    render plain: "stopped"
  end

  private

  def logged_in?
    self.class.test_actor.present?
  end

  def current_resource
    self.class.test_actor
  end

  def r18_gate_path(pt:)
    "/test/r18_gate?pt=#{ERB::Util.url_encode(pt)}"
  end

  def r18_blocked_path
    "/test/r18_blocked"
  end

  def r18_stopped_path
    "/test/r18_stopped"
  end

  def r18_fallback_path
    "/fallback"
  end
end

class R18GateTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  Actor = Struct.new(:birthdate, :user_preference, keyword_init: true)

  Stopper =
    Struct.new(:state) do
      def approved? = state == :approved

      def denied? = state == :deny

      def enabled? = denied?
    end

  Preference =
    Struct.new(:client_preference_adult_content_gate, keyword_init: true) do
      def adult_content_gate = client_preference_adult_content_gate
    end

  setup do
    R18GateTestController.test_actor = nil
    Rails.application.routes.draw do
      get "/test/r18" => "r18_gate_test#show"
      post "/test/r18" => "r18_gate_test#create"
      get "/test/r18_gate" => "r18_gate_test#gate"
      post "/test/r18_ack" => "r18_gate_test#acknowledge"
      get "/test/r18_blocked" => "r18_gate_test#blocked"
      get "/test/r18_stopped" => "r18_gate_test#stopped"
    end
  end

  teardown do
    R18GateTestController.test_actor = nil
    Rails.application.reload_routes!
  end

  test "anonymous GET redirects to age gate" do
    get "/test/r18"

    assert_response :redirect
    assert_equal "/test/r18_gate", URI.parse(response.location).path
  end

  test "anonymous acknowledged GET passes" do
    post "/test/r18_ack", params: { yes: "1", pt: "/test/r18" }
    follow_redirect!

    assert_response :success
    assert_equal "r18 content", response.body
  end

  test "anonymous unsafe pt falls back" do
    post "/test/r18_ack", params: { yes: "1", pt: "https://evil.example/r18" }

    assert_redirected_to "/fallback"
  end

  test "anonymous POST is forbidden" do
    post "/test/r18"

    assert_response :forbidden
  end

  test "logged in minor cannot pass with acknowledged cookie" do
    post "/test/r18_ack", params: { yes: "1", pt: "/test/r18" }
    R18GateTestController.test_actor = Actor.new(birthdate: "2010-01-01")

    get "/test/r18"

    assert_redirected_to "/test/r18_blocked"
  end

  test "logged in adult passes when stopper is approved" do
    preference = Preference.new(client_preference_adult_content_gate: Stopper.new(:approved))
    R18GateTestController.test_actor = Actor.new(birthdate: "2000-01-01", user_preference: preference)

    get "/test/r18"

    assert_response :success
    assert_equal "r18 content", response.body
  end

  test "logged in adult with stopper is redirected to stopped page" do
    preference = Preference.new(client_preference_adult_content_gate: Stopper.new(:deny))
    R18GateTestController.test_actor = Actor.new(birthdate: "2000-01-01", user_preference: preference)

    get "/test/r18"

    assert_redirected_to "/test/r18_stopped"
  end

  test "logged in adult with undecided stopper is asked" do
    preference = Preference.new(client_preference_adult_content_gate: Stopper.new(:nothing))
    R18GateTestController.test_actor = Actor.new(birthdate: "2000-01-01", user_preference: preference)

    get "/test/r18"

    assert_redirected_to "/test/r18_gate?pt=%2Ftest%2Fr18"
  end

  test "logged in adult with token preference stopper is redirected to stopped page" do
    preference = ::Actor::Preference.new(adult_content_gate: "deny")
    R18GateTestController.test_actor = Actor.new(birthdate: "2000-01-01", user_preference: preference)

    get "/test/r18"

    assert_redirected_to "/test/r18_stopped"
  end

  test "logged in leap day user uses canonical R18 age calculation" do
    travel_to Time.zone.local(2030, 2, 28, 12, 0, 0) do
      preference = Preference.new(client_preference_adult_content_gate: Stopper.new(:approved))
      R18GateTestController.test_actor = Actor.new(birthdate: "2012-02-29", user_preference: preference)

      get "/test/r18"

      assert_response :success
    end
  end
end
