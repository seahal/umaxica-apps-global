# typed: false
# frozen_string_literal: true

require "test_helper"

module Concerns
  class ApplicationControllerCommonPatternsTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    ALL_CONTROLLER_FILES = Dir.glob(Rails.root.join("app/controllers/**/application_controller.rb").to_s)
      .reject { |f| f.include?("/vendor/") }
      .reject { |f| f.end_with?("/controllers/application_controller.rb") }
      .reject { |f| f.include?("/sign/com/") }
      .reject { |f| f.include?("/jump/") }
      .sort
    CONTROLLER_FILES =
      ALL_CONTROLLER_FILES.index_with do |file|
        {
          content: File.read(file),
          name: file.gsub(Rails.root.join("app/controllers/").to_s, "")
            .gsub("/application_controller.rb", "")
            .gsub("/", "::")
            .gsub("_", " ")
            .split.map(&:capitalize).join("::"),
          path_name: file.gsub(Rails.root.join("app/controllers/").to_s, "")
            .gsub("/application_controller.rb", "")
            .gsub("/", "::"),
        }
      end

    test "all application controllers include RateLimit" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:name]

        assert_includes content, "RateLimit",
                        "#{controller_name} should include RateLimit"
      end
    end

    test "all application controllers include ActorSupport" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:name]

        assert_includes content, "ActorSupport",
                        "#{controller_name} should include ActorSupport"
      end
    end

    test "all application controllers include Session" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:name]

        assert_includes content, "Session",
                        "#{controller_name} should include Session"
      end
    end

    test "all application controllers include Finisher" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:name]

        assert_includes content, "Finisher",
                        "#{controller_name} should include Finisher"
      end
    end

    test "all application controllers have cleanup action" do
      pattern = %r{
        (after_action|append_after_action)\s+:(purge_current|finish_request)
        |
        (prepend_around_action|around_action)\s+:with_actor_lifecycle
    }x

      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_match(
          pattern,
          content,
          "#{controller_name} should have cleanup action",
        )
      end
    end

    test "application controllers do not register removed default rate limit callback" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_not_includes content, "before_action :check_default_rate_limit",
                            "#{controller_name} should not use removed default rate limit callback"
      end
    end

    test "all application controllers set current context before reset flash" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_match(
          /before_action :set_current_context\s+before_action :reset_flash/,
          content,
          "#{controller_name} should set current context before reset flash",
        )
      end
    end

    test "application controllers with user auth include required concerns" do
      user_controllers =
        CONTROLLER_FILES.values.select do |controller|
          controller[:content].include?("Authentication::Client")
        end

      user_controllers.each do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_includes content, "Authorization::Client",
                        "#{controller_name} should include Authorization::Client when using Authentication::Client"
        assert_includes content, "Verification::Client",
                        "#{controller_name} should include Verification::Client when using Authentication::Client"
      end
    end

    test "application controllers with staff auth include required concerns" do
      staff_controllers =
        CONTROLLER_FILES.values.select do |controller|
          controller[:content].include?("Authentication::Operator")
        end

      staff_controllers.each do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_includes content, "Authorization::Operator",
                        "#{controller_name} should include Authorization::Operator when using Authentication::Operator"
        assert_includes content, "Verification::Operator",
                        "#{controller_name} should include Verification::Operator when using Authentication::Operator"
      end
    end

    test "application controllers with visitor auth include required concerns" do
      visitor_controllers =
        CONTROLLER_FILES.values.select do |controller|
          controller[:content].include?("Authentication::Visitor")
        end

      visitor_controllers.each do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_includes content, "Authorization::Visitor",
                        "#{controller_name} should include Authorization::Visitor when using Authentication::Visitor"
        assert_includes content, "Verification::Visitor",
                        "#{controller_name} should include Verification::Visitor when using Authentication::Visitor"
      end
    end

    test "application controllers with OIDC include Oidc::SsoInitiator" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        if content.include?("oidc_client_id")
          assert_includes content, "Oidc::SsoInitiator",
                          "#{controller_name} with oidc_client_id should include Oidc::SsoInitiator"
        end
      end
    end
  end
end
