# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/committee_helper"

module Sign
  module App
    module Edge
      module V0
        class HealthsControllerTest < ActionDispatch::IntegrationTest
          include CommitteeHelper

          test "returns success for default format" do
            get sign_app_edge_v0_health_url(ri: "jp")

            assert_response :success
            assert_includes response.body, "OK"
            assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, response.body)
          end

          test "returns success for explicit html format" do
            get sign_app_edge_v0_health_url(format: :html, ri: "jp")

            assert_response :success
            assert_includes response.body, "OK"
            assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, response.body)
          end

          test "returns OK status payload for json format" do
            get sign_app_edge_v0_health_url(format: :json, ri: "jp")

            assert_response :success
            assert_equal "OK", response.parsed_body["status"]
            assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, response.parsed_body["timestamp"])
            assert response.parsed_body.key?("revision")
          end

          test "raises error for unsupported yaml format" do
            get sign_app_edge_v0_health_url(format: :yaml, ri: "jp")

            assert_response :success
            assert_equal "OK", response.parsed_body["status"]
            assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, response.parsed_body["timestamp"])
            assert response.parsed_body.key?("revision")
          end

          test "json response conforms to OpenAPI schema" do
            get sign_app_edge_v0_health_url(ri: "jp"), headers: { "Accept" => "application/json" }

            assert_response :success
            assert response.parsed_body.key?("revision")
            assert_response_schema_confirm
          end
        end
      end
    end
  end
end
