# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class PrivateAuthorizationPostconditionInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "authentication lifecycle verifies resource authorization after private actions" do
        source = Rails.root.join("app/controllers/concerns/authentication_base.rb").read

        assert_includes source, "after_action :verify_private_action_authorized!"
        assert_includes source, "self.class.authentication_mode_for(action_name) == :private"
        assert_includes source, "verify_authorized"
      end

      test "authorization postcondition bypass APIs are absent from application controllers" do
        offenders =
          Rails.root.glob("app/controllers/**/*.rb").filter do |path|
            path.read.match?(/skip_verify_authorized|skip_after_action\s+:verify_private_action_authorized/)
          end

        assert_empty offenders
      end
    end
  end
end
