# typed: false
# frozen_string_literal: true

require "test_helper"

module Acme
  module Org
    module Edge
      module V0
        class DbscControllerTest < ActiveSupport::TestCase
          test "skips transparent refresh access token callback" do
            callbacks = DbscController._process_action_callbacks
            before_filters = callbacks.select { |callback| callback.kind == :before }.map(&:filter)

            assert_not_includes before_filters, :transparent_refresh_access_token
            assert_not_includes before_filters, :enforce_verification_if_required
            assert_includes before_filters, :set_preferences_cookie
          end
        end
      end
    end
  end
end
