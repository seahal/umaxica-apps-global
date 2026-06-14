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
    assert logged.all? { |entry| entry.dig(:data, :category) == "application" }
    assert logged.all? { |entry| entry.dig(:data, :blocked_uri) == "https://cdn.example.test/script.js" }
    assert logged.all? { |entry| entry.dig(:data, :script_sample).nil? }
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
      [ENV.fetch("ACME_SERVICE_URL"), :acme_app_csp_violation_report_path],
      [ENV.fetch("ACME_CORPORATE_URL"), :acme_com_csp_violation_report_path],
      [ENV.fetch("ACME_STAFF_URL"), :acme_org_csp_violation_report_path],
      [ENV.fetch("ACME_NETWORK_URL"), :acme_network_csp_violation_report_path],
      [ENV.fetch("ACME_DEVELOPER_URL"), :acme_developer_csp_violation_report_path],
      [ENV.fetch("SIGN_SERVICE_URL"), :sign_app_csp_violation_report_path],
      [ENV.fetch("SIGN_CORPORATE_URL"), :sign_com_csp_violation_report_path],
      [ENV.fetch("SIGN_STAFF_URL"), :sign_org_csp_violation_report_path],
      [ENV["CORE_SERVICE_URL"] || "core.app.localhost", :core_app_csp_violation_report_path],
      [ENV["CORE_CORPORATE_URL"] || "core.com.localhost", :core_com_csp_violation_report_path],
      [ENV["CORE_STAFF_URL"] || "core.org.localhost", :core_org_csp_violation_report_path],
      [ENV["BASE_SERVICE_URL"] || "base.app.localhost", :base_app_csp_violation_report_path],
      [ENV["BASE_CORPORATE_URL"] || "base.com.localhost", :base_com_csp_violation_report_path],
      [ENV["BASE_STAFF_URL"] || "base.org.localhost", :base_org_csp_violation_report_path],
      [ENV["PALM_SERVICE_URL"] || "palm.app.localhost", :palm_app_csp_violation_report_path],
      [ENV["DOCS_SERVICE_URL"] || "docs.app.localhost", :docs_app_csp_violation_report_path],
      [ENV["DOCS_CORPORATE_URL"] || "docs.com.localhost", :docs_com_csp_violation_report_path],
      [ENV["DOCS_STAFF_URL"] || "docs.org.localhost", :docs_org_csp_violation_report_path],
      [ENV["HELP_SERVICE_URL"] || "help.app.localhost", :help_app_csp_violation_report_path],
      [ENV["HELP_CORPORATE_URL"] || "help.com.localhost", :help_com_csp_violation_report_path],
      [ENV["HELP_STAFF_URL"] || "help.org.localhost", :help_org_csp_violation_report_path],
      [ENV["NEWS_SERVICE_URL"] || "news.app.localhost", :news_app_csp_violation_report_path],
      [ENV["NEWS_CORPORATE_URL"] || "news.com.localhost", :news_com_csp_violation_report_path],
      [ENV["NEWS_STAFF_URL"] || "news.org.localhost", :news_org_csp_violation_report_path],
    ]
  end

  def csp_report_payload
    {
      "csp-report" => {
        "document-uri" => "https://app.example.test/settings?token=secret#fragment",
        "blocked-uri" => "https://cdn.example.test/script.js?session=secret#inline",
        "effective-directive" => "script-src",
        "script-sample" => "secret inline sample",
      },
    }
  end

  def json_headers
    { "CONTENT_TYPE" => "application/json" }
  end

  def normalize_host(host)
    CommonRedirect.normalize_host(host)
  end
end
