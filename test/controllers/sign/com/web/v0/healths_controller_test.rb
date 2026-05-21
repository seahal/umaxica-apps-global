# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    module Web
      module V0
        class HealthsControllerTest < ActionDispatch::IntegrationTest
          setup do
            host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
          end

          test "returns OK status payload" do
            get sign_com_web_v0_health_url(format: :json, ri: "jp")

            assert_response :success
            assert_equal "OK", response.parsed_body["status"]
            assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, response.parsed_body["timestamp"])
            assert response.parsed_body.key?("revision")
          end
        end
      end
    end
  end
end
