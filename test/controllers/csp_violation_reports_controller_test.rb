# typed: false
# frozen_string_literal: true

require "test_helper"

class CspViolationReportsControllerTest < ActionDispatch::IntegrationTest
  setup { clear_rate_limit_store }
  teardown { clear_rate_limit_store }

  test "routes record CSP violations for representative surfaces through Rails event" do
    events = []

    Rails.event.stub(:notify, ->(name, payload) { events << [name, payload] }) do
      csp_report_cases.each do |host, helper_name|
        host!(host)

        post public_send(helper_name), params: csp_report_payload, as: :json

        assert_response :no_content
      end
    end

    assert_equal csp_report_cases.size, events.size
    assert events.all? { |name, _payload| name == CspViolationReportIntake::EVENT_NAME }
    assert events.all? { |_name, payload| payload[:category] == "application" }
    assert events.all? { |_name, payload| payload[:blocked_uri] == "https://cdn.example.test/script.js" }
    assert events.all? { |_name, payload| payload[:script_sample].nil? }
  end

  test "post without csrf token returns no content" do
    with_forgery_protection do
      host! ENV.fetch("SIGN_SERVICE_URL")

      post sign_app_csp_violation_report_path,
           params: csp_report_payload.to_json,
           headers: {
             "CONTENT_TYPE" => "application/csp-report",
           }
    end

    assert_response :no_content
  end

  test "accepts CSP report with Origin null when forgery protection is enabled" do
    with_forgery_protection do
      host! ENV.fetch("SIGN_SERVICE_URL")

      post sign_app_csp_violation_report_path,
           params: csp_report_payload.to_json,
           headers: {
             "CONTENT_TYPE" => "application/csp-report",
             "HTTP_ORIGIN" => "null",
           }
    end

    assert_response :no_content
  end

  test "application csp report content type returns no content" do
    host! ENV.fetch("SIGN_SERVICE_URL")

    post sign_app_csp_violation_report_path,
         params: csp_report_payload.to_json,
         headers: { "CONTENT_TYPE" => "application/csp-report" }

    assert_response :no_content
  end

  test "application json content type returns no content" do
    host! ENV.fetch("SIGN_SERVICE_URL")

    post sign_app_csp_violation_report_path,
         params: csp_report_payload.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :no_content
  end

  test "malformed JSON still returns no content and does not record an event" do
    host! ENV.fetch("SIGN_SERVICE_URL")

    events = []
    Rails.event.stub(:notify, ->(name, payload) { events << [name, payload] }) do
      post sign_app_csp_violation_report_path, params: "{not valid json", headers: json_headers

      assert_response :no_content
    end

    assert_empty events
  end

  test "oversized content length returns no content without calling intake" do
    host! ENV.fetch("SIGN_SERVICE_URL")

    called = false
    CspViolationReportIntake.stub(:call, ->(**) { called = true }) do
      post sign_app_csp_violation_report_path,
           params: "",
           headers: {
             "CONTENT_TYPE" => "application/csp-report",
             "CONTENT_LENGTH" => (CspViolationReportIntake::MAX_BODY_BYTES + 1).to_s,
           }
    end

    assert_response :no_content
    assert_not called
  end

  test "rate limit overflow still returns no content" do
    host! ENV.fetch("SIGN_SERVICE_URL")

    Rails.event.stub(:notify, ->(_name, _payload) { }) do
      121.times do
        post sign_app_csp_violation_report_path, params: csp_report_payload, as: :json
      end
    end

    assert_response :no_content
  end

  test "controller calls intake but does not call subscriber directly" do
    host! ENV.fetch("SIGN_SERVICE_URL")

    called = false
    CspViolationReportIntake.stub(:call, ->(**) { called = true }) do
      CspViolationSubscriber.stub(
        :new,
        -> { raise RuntimeError, "subscriber must not be instantiated by controller" },
      ) do
        post sign_app_csp_violation_report_path, params: csp_report_payload, as: :json
      end
    end

    assert_response :no_content
    assert called
  end

  test "ordinary state-changing endpoint still rejects tokenless post when forgery protection is enabled" do
    host! ENV.fetch("BASE_SERVICE_URL", "base.app.localhost")

    with_forgery_protection do
      post base_app_sign_out_url(ri: "jp")
    end

    assert_response :unprocessable_content
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
      [ENV["CORE_NETWORK_URL"] || "core.net.localhost", :core_network_csp_violation_report_path],
      [ENV["CORE_DEVELOPER_URL"] || "core.dev.localhost", :core_developer_csp_violation_report_path],
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

  def clear_rate_limit_store
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end
end
