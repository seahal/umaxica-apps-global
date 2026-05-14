# typed: false
# frozen_string_literal: true

require "test_helper"

module Concerns
  class ApplicationControllerCommonPatternsTest < ActiveSupport::TestCase
    ALL_CONTROLLER_FILES = Dir.glob(Rails.root.join("app/controllers/**/application_controller.rb").to_s)
      .reject { |f| f.include?("/vendor/") }
      .reject { |f| f.end_with?("/controllers/application_controller.rb") }
      .reject { |f| f.include?("/sign/com/") }
      .reject { |f| f.include?("/jump/") }
      .sort

    test "all application controllers include RateLimit" do
      ALL_CONTROLLER_FILES.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")
          .gsub("_", " ")
          .split.map(&:capitalize).join("::")

        assert_includes content, "RateLimit",
                        "#{controller_name} should include RateLimit"
      end
    end

    test "all application controllers include CurrentSupport" do
      ALL_CONTROLLER_FILES.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")
          .gsub("_", " ")
          .split.map(&:capitalize).join("::")

        assert_includes content, "CurrentSupport",
                        "#{controller_name} should include CurrentSupport"
      end
    end

    test "all application controllers include Session" do
      ALL_CONTROLLER_FILES.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")
          .gsub("_", " ")
          .split.map(&:capitalize).join("::")

        assert_includes content, "Session",
                        "#{controller_name} should include Session"
      end
    end

    test "all application controllers include Finisher" do
      ALL_CONTROLLER_FILES.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")
          .gsub("_", " ")
          .split.map(&:capitalize).join("::")

        assert_includes content, "Finisher",
                        "#{controller_name} should include Finisher"
      end
    end

    test "all application controllers have cleanup after_action" do
      ALL_CONTROLLER_FILES.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")

        assert_match(
          /(after_action|append_after_action) :(purge_current|finish_request)/, content,
          "#{controller_name} should have :purge_current or :finish_request after_action",
        )
      end
    end

    test "all application controllers have check_default_rate_limit before_action" do
      ALL_CONTROLLER_FILES.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")

        assert_includes content, "before_action :check_default_rate_limit",
                        "#{controller_name} should have before_action :check_default_rate_limit"
      end
    end

    test "all application controllers have reset_flash immediately after check_default_rate_limit" do
      ALL_CONTROLLER_FILES.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")

        assert_match(
          /before_action :check_default_rate_limit\s+before_action :reset_flash/,
          content,
          "#{controller_name} should have before_action :reset_flash immediately after check_default_rate_limit",
        )
      end
    end

    test "application controllers with user auth include required concerns" do
      user_controllers =
        ALL_CONTROLLER_FILES.select do |file|
          content = File.read(file)
          content.include?("Authentication::User")
        end

      user_controllers.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")

        assert_includes content, "Authorization::User",
                        "#{controller_name} should include Authorization::User when using Authentication::User"
        assert_includes content, "Verification::User",
                        "#{controller_name} should include Verification::User when using Authentication::User"
      end
    end

    test "application controllers with staff auth include required concerns" do
      staff_controllers =
        ALL_CONTROLLER_FILES.select do |file|
          content = File.read(file)
          content.include?("Authentication::Operator")
        end

      staff_controllers.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")

        assert_includes content, "Authorization::Operator",
                        "#{controller_name} should include Authorization::Operator when using Authentication::Operator"
        assert_includes content, "Verification::Operator",
                        "#{controller_name} should include Verification::Operator when using Authentication::Operator"
      end
    end

    test "application controllers with visitor auth include required concerns" do
      visitor_controllers =
        ALL_CONTROLLER_FILES.select do |file|
          content = File.read(file)
          content.include?("Authentication::Visitor")
        end

      visitor_controllers.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")

        assert_includes content, "Authorization::Visitor",
                        "#{controller_name} should include Authorization::Visitor when using Authentication::Visitor"
        assert_includes content, "Verification::Visitor",
                        "#{controller_name} should include Verification::Visitor when using Authentication::Visitor"
      end
    end

    test "application controllers with OIDC include Oidc::SsoInitiator" do
      ALL_CONTROLLER_FILES.each do |file|
        content = File.read(file)
        controller_name = file.gsub(Rails.root.join("app/controllers/").to_s, "")
          .gsub("/application_controller.rb", "")
          .gsub("/", "::")

        if content.include?("oidc_client_id")
          assert_includes content, "Oidc::SsoInitiator",
                          "#{controller_name} with oidc_client_id should include Oidc::SsoInitiator"
        end
      end
    end
  end
end
