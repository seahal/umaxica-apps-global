# typed: false
# frozen_string_literal: true

require "test_helper"

module Jump
  module App
    class OpenBoundaryTestController < OpenController
      def show
        render json: {
          actor_type: Actor.actor_type.to_s,
          signed_in: Actor.signed_in?,
          tld: Actor.tld.to_s,
        }
      end
    end
  end
end

class JumpBoundaryControllerTest < ActionDispatch::IntegrationTest
  setup { Actor.reset }

  teardown do
    Rails.application.reload_routes!
    Actor.reset
  end

  test "jump bare controllers stay free of auth current and policy machinery" do
    [
      Jump::App::BareController,
      Jump::Com::BareController,
      Jump::Org::BareController,
    ].each do |controller|
      assert_not_includes controller.ancestors, ActorSupport
      assert_not_includes controller.ancestors, Authentication::Client
      assert_not_includes controller.ancestors, Authentication::Visitor
      assert_not_includes controller.ancestors, Authentication::Operator
      assert_empty controller.access_policy_rules if controller.respond_to?(:access_policy_rules)

      assert_not_includes before_filters_for(controller), :enforce_access_policy!
    end
  end

  test "jump open controllers provide anonymous actor context only" do
    [
      Jump::App::OpenController,
      Jump::Com::OpenController,
      Jump::Org::OpenController,
    ].each do |controller|
      assert_equal ActionController::Base, controller.superclass
      assert_includes controller.ancestors, ActorSupport
      assert_includes controller.ancestors, RateLimit
      assert_not_includes controller.ancestors, Authentication::Client
      assert_not_includes controller.ancestors, Authentication::Visitor
      assert_not_includes controller.ancestors, Authentication::Operator
      assert_empty controller.access_policy_rules if controller.respond_to?(:access_policy_rules)

      assert_not_includes before_filters_for(controller), :enforce_access_policy!

      around_filters = controller._process_action_callbacks.select { |callback| callback.kind == :around }.map(&:filter)

      assert_operator before_filters_for(controller).index(:set_current_context), :<,
                      before_filters_for(controller).index(:set_current_actor)
      assert_includes around_filters, :with_actor_lifecycle
    end
  end

  test "jump application controllers inherit directly from ActionController base" do
    [
      Jump::App::ApplicationController,
      Jump::Com::ApplicationController,
      Jump::Org::ApplicationController,
    ].each do |controller|
      assert_equal ActionController::Base, controller.superclass
      assert_includes controller.ancestors, ActorSupport
      assert_includes controller.ancestors, RateLimit
    end
  end

  test "jump app open request resolves anonymous actor context and clears it after response" do
    Rails.application.routes.draw do
      get "/jump_open_boundary", to: Jump::App::OpenBoundaryTestController.action(:show)
    end

    host! ENV.fetch("JUMP_SERVICE_URL").delete_suffix("/")
    get "/jump_open_boundary"

    assert_response :success
    assert_equal "unauthenticated", response.parsed_body["actor_type"]
    assert_not response.parsed_body["signed_in"]
    assert_equal "app", response.parsed_body["tld"]
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.tld
  end

  test "jump does not define private or guest controller boundaries" do
    [
      Jump::App,
      Jump::Com,
      Jump::Org,
    ].each do |namespace|
      assert_not namespace.const_defined?(:PrivateController, false)
      assert_not namespace.const_defined?(:GuestController, false)
    end
  end

  private

  def before_filters_for(controller)
    controller._process_action_callbacks.select { |callback| callback.kind == :before }.map(&:filter)
  end
end
