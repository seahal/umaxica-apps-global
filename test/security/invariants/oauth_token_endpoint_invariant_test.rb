# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class OauthTokenEndpointInvariantTest < ActiveSupport::TestCase
      fixtures_none!

      TOKEN_CONTROLLERS = {
        "app/controllers/sign/app/tokens_controller.rb" => Sign::App::TokensController,
        "app/controllers/sign/com/tokens_controller.rb" => Sign::Com::TokensController,
        "app/controllers/sign/org/tokens_controller.rb" => Sign::Org::TokensController,
      }.freeze

      test "token endpoints are explicit protocol endpoints" do
        violations =
          TOKEN_CONTROLLERS.filter_map do |path, controller|
            content = Rails.root.join(path).read
            issues = []
            issues << "missing null_session create boundary" unless content.include?("protect_from_forgery with: :null_session, only: :create")
            issues << "missing transparent refresh skip" unless content.include?("skip_before_action :transparent_refresh_access_token")
            issues << "missing create rate limit" unless content.match?(/\brate_limit\s+to:\s*\d+,\s*within:\s*1\.minute,\s*only:\s*:create\b/)
            issues << "not open protocol endpoint" unless controller.authentication_mode_for(:create) == :open
            next if issues.empty?

            "#{controller.name}: #{issues.join(", ")}"
          end

        assert_empty violations, "OAuth token endpoint protocol boundary drifted:\n#{violations.join("\n")}"
      end

      test "token endpoints do not mutate browser session or cookies directly" do
        forbidden = /\b(?:session|cookies)\s*(?:\[|\.|=)|\breset_session\b|\blog_in\b|\blog_out\b/
        offenders =
          TOKEN_CONTROLLERS.keys.flat_map do |path|
            content = Rails.root.join(path).read
            content.each_line.with_index(1).filter_map do |line, line_number|
              next unless line.match?(forbidden)

              "#{path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders, "OAuth token endpoints must not mutate browser session/cookies:\n#{offenders.join("\n")}"
      end
    end
  end
end
