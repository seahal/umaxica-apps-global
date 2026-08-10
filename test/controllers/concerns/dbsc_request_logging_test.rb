# frozen_string_literal: true

require "test_helper"

class DbscRequestLoggingTest < ActiveSupport::TestCase
  class Harness
    include DbscRequestLogging

    attr_reader :request

    def initialize(request)
      @request = request
    end

    def emit
      log_dbsc_request_observability!
    end
  end

  test "logs DBSC header presence without credential values or query parameters" do
    request = ActionDispatch::TestRequest.create(
      "PATH_INFO" => "/edge/v0/dbsc",
      "QUERY_STRING" => "token=audit-query-secret",
      "REQUEST_METHOD" => "POST",
    )
    session_id = "audit-session-id-not-a-real-secret"
    proof = "audit-proof-not-a-real-secret"
    challenge = "audit-challenge-not-a-real-secret"
    request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID] = session_id
    request.headers[AuthIoKeys::Headers::DBSC_RESPONSE] = proof
    request.headers[AuthIoKeys::Headers::DBSC_CHALLENGE] = challenge

    messages = []
    Rails.logger.stub(:info, ->(message) { messages << message }) do
      Harness.new(request).emit
    end

    combined = messages.join("\n")

    assert_includes combined, "dbsc.request"
    assert_includes combined, AuthIoKeys::Headers::DBSC_SESSION_ID
    assert_includes combined, AuthIoKeys::Headers::DBSC_RESPONSE
    assert_includes combined, AuthIoKeys::Headers::DBSC_CHALLENGE
    assert_not_includes combined, session_id
    assert_not_includes combined, proof
    assert_not_includes combined, challenge
    assert_not_includes combined, "audit-query-secret"
  end
end
