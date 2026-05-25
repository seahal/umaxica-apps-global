# typed: false
# frozen_string_literal: true

require "test_helper"

class CspViolationReportsControllerTest < ActionDispatch::IntegrationTest
  test "routes record CSP violations for representative surfaces" do
    logged = []

    Rails.logger.stub(
      :info, proc { |message = nil|
               logged << JSON.parse(message.to_s, symbolize_names: true) if message
             },
    ) do
      csp_report_cases.each do |host, helper_name|
        host!(host)

        post public_send(helper_name), params: csp_report_payload, as: :json

        assert_response :no_content
      end
    end

    assert_equal csp_report_cases.size, logged.size
    assert logged.all? { |entry| entry[:event] == "security.csp_violation" }
    assert logged.all? { |entry| entry[:data] == { foo: "bar" } }
  end

  test "malformed JSON still returns no_content and does not record an event" do
    host! ENV.fetch("SIGN_SERVICE_URL")

    logged = []
    Rails.logger.stub(:info, proc { |message = nil| logged << message if message }) do
      post sign_app_csp_violation_report_path, params: "{not valid json", headers: json_headers

      assert_response :no_content
    end

    assert_empty logged
  end

  private

  def csp_report_cases
    [
      [ENV.fetch("APEX_SERVICE_URL"), :apex_app_csp_violation_report_path],
      [ENV.fetch("APEX_CORPORATE_URL"), :apex_com_csp_violation_report_path],
      [ENV.fetch("APEX_STAFF_URL"), :apex_org_csp_violation_report_path],
      [ENV.fetch("APEX_NETWORK_URL"), :apex_network_csp_violation_report_path],
      [ENV.fetch("APEX_DEVELOPER_URL"), :apex_developer_csp_violation_report_path],
      [normalize_host(ENV.fetch("JUMP_SERVICE_URL")), :jump_app_csp_violation_report_path],
      [ENV.fetch("JUMP_CORPORATE_URL"), :jump_com_csp_violation_report_path],
      [ENV.fetch("JUMP_STAFF_URL"), :jump_org_csp_violation_report_path],
      [ENV.fetch("SIGN_SERVICE_URL"), :sign_app_csp_violation_report_path],
      [ENV.fetch("SIGN_CORPORATE_URL"), :sign_com_csp_violation_report_path],
      [ENV.fetch("SIGN_STAFF_URL"), :sign_org_csp_violation_report_path],
    ]
  end

  def csp_report_payload
    {
      "csp-report" => {
        "foo" => "bar",
      },
    }
  end

  def json_headers
    { "CONTENT_TYPE" => "application/json" }
  end

  def normalize_host(host)
    Common::Redirect.normalize_host(host)
  end
end
