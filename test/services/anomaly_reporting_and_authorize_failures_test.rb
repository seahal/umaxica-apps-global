# typed: false
# frozen_string_literal: true

require "test_helper"

# Two boundaries whose whole job is to not make a bad situation worse: a JWT
# anomaly report that itself fails must be swallowed rather than replacing the
# anomaly it was reporting, and an authorization request that fails to persist
# has to answer the OAuth error the client can act on rather than raising.
class AnomalyReportingAndAuthorizeFailuresTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a failure while reporting a JWT anomaly is swallowed rather than replacing it" do
    unavailable = Object.new
    unavailable.define_singleton_method(:warn) { |*| raise IOError, "log sink unavailable" }
    unavailable.define_singleton_method(:info) { |*| raise IOError, "log sink unavailable" }
    unavailable.define_singleton_method(:error) { |*| nil }

    Rails.stub(:logger, unavailable) do
      assert_nil JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: "client", host: "auth.umaxica.app", reason: "MISSING_ISS",
      )
    end
  end

  test "a JWT anomaly is reported with the claim names that were missing" do
    reported = []
    logger = Object.new
    logger.define_singleton_method(:warn) { |message| reported << message }
    logger.define_singleton_method(:info) { |message| reported << message }
    logger.define_singleton_method(:error) { |message| reported << message }

    Rails.stub(:logger, logger) do
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: "client", host: "auth.umaxica.app", reason: "MISSING_ISS",
        payload: { "aud" => "umaxica-api" },
      )
    end

    assert_predicate reported, :present?
    assert(reported.any? { |message| message.to_s.include?("MISSING_ISS") })
  end

  # Each way an authorization request can be refused maps to a distinct OAuth
  # error, because the client decides whether to retry from that code alone.
  test "a persistence failure answers server_error rather than raising out of the endpoint" do
    coordinator =
      OidcAuthorizeCoordinator.new(params: {}, resource: nil, session_token: nil)
    coordinator.define_singleton_method(:validate_request!) do
      raise ActiveRecord::RecordInvalid, ClientAuthorizationCode.new
    end

    result = coordinator.call

    assert_not result.success
    assert_equal "server_error", result.error
  end

  test "an unknown client and an invalid scope answer their own OAuth errors" do
    {
      OidcClientRegistry::ClientNotFound => "unauthorized_client",
      OidcAuthorizeRequestResolver::InvalidScope => "invalid_scope",
      OidcClientRegistry::InvalidRedirectUri => "invalid_request",
      ArgumentError => "invalid_request",
    }.each do |error_class, expected|
      coordinator = OidcAuthorizeCoordinator.new(params: {}, resource: nil, session_token: nil)
      coordinator.define_singleton_method(:validate_request!) { raise error_class, "refused" }

      assert_equal expected, coordinator.call.error, error_class.name
    end
  end
end
