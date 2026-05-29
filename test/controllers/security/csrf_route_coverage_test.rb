# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/csrf_route_coverage_helper"

module Security
  class CsrfRouteCoverageTest < ActiveSupport::TestCase
    include CsrfRouteCoverageHelper

    fixtures_none!

    NULL_SESSION_STRATEGY = ActionController::RequestForgeryProtection::ProtectionMethods::NullSession
    PROTOCOL_ENDPOINTS = [
      %r{\A/oauth/token(?:\(\.:format\))?\z},
      %r{\A/oauth/revoke(?:\(\.:format\))?\z},
    ].freeze

    test "state-changing application routes do not use null-session csrf handling" do
      violations =
        state_changing_application_route_targets.filter_map do |target|
          next if protocol_endpoint?(target)
          next unless target.fetch(:controller_class).forgery_protection_strategy == NULL_SESSION_STRATEGY

          "#{target.fetch(:verb)} #{target.fetch(:path)} -> " \
            "#{target.fetch(:controller)}##{target.fetch(:action)}"
        end

      assert_empty violations,
                   "State-changing routes must reject missing/invalid CSRF tokens instead of " \
                   "using null_session. Review:\n  #{violations.join("\n  ")}"
    end

    private

    def protocol_endpoint?(target)
      PROTOCOL_ENDPOINTS.any? { |pattern| pattern.match?(target.fetch(:path)) }
    end
  end
end
