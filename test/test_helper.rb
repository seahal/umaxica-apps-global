# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["AUTH_SERVICE_URL"] = "auth.app.localhost"
ENV["AUTH_CORPORATE_URL"] = "auth.com.localhost"
ENV["AUTH_STAFF_URL"] = "auth.org.localhost"
ENV["PUBLIC_AUTH_SERVICE_URL"] = "auth.app.localhost"
ENV["PUBLIC_AUTH_CORPORATE_URL"] = "auth.com.localhost"
ENV["PUBLIC_AUTH_STAFF_URL"] = "auth.org.localhost"
ENV["PRIVATE_AUTH_SERVICE_URL"] = "auth.app.localhost"
ENV["PRIVATE_AUTH_CORPORATE_URL"] = "auth.com.localhost"
ENV["PRIVATE_AUTH_STAFF_URL"] = "auth.org.localhost"
ENV["SMTP_FROM_ADDRESS_APP"] = "from@umaxica.app"
RubyVM::YJIT.enable if defined?(RubyVM::YJIT)

require_relative "../config/environment"
require "rails/test_help"
require_relative "support/parallel_test_database_cloner"

module AuthenticationHarness
  TEST_BROWSER_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV.fetch("DEFAULT_URL_HOST", nil)
    headers = { "Client-Agent" => TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    authenticated_resource_headers(
      user,
      host: host,
      headers: headers,
      session_public_id: session_public_id,
      resource_type: "client",
      session_header: "X-TEST-CURRENT-USER",
    )
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    authenticated_resource_headers(
      staff,
      host: host,
      headers: headers,
      session_public_id: session_public_id,
      resource_type: "operator",
      session_header: "X-TEST-CURRENT-STAFF",
    )
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    authenticated_resource_headers(
      visitor,
      host: host,
      headers: headers,
      session_public_id: session_public_id,
      resource_type: "visitor",
      session_header: "X-TEST-CURRENT-RESOURCE",
    )
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def submit_step_up_completion_if_present!(host: nil, headers: {})
    return unless respond_to?(:response) && response.media_type == "text/html"
    return unless response.body.include?("step-up-completion-form")

    form = response.parsed_body.at_css("form#step-up-completion-form")
    raise StandardError, "step-up completion form missing" unless form

    params = {}
    form.css("input").each do |input|
      name = input["name"]
      params[name] = input["value"] if name.present?
    end

    action = form["action"].to_s
    action_uri = URI.parse(action)
    completion_headers = headers.except("Host", :Host).merge(host_headers(action_uri.host.presence || host))
    post(action, params: params, headers: completion_headers)
  end

  private

  def authenticated_resource_headers(resource, host:, headers:, session_public_id:, resource_type:, session_header:)
    token_record = authentication_harness_session_token(resource, session_public_id: session_public_id)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil)
    access_token = jwt_access_token_for(
      resource,
      host: host_value,
      session_public_id: token_record.public_id,
      resource_type: resource_type,
    )

    host_headers(host)
      .merge(headers)
      .merge(
        session_header => resource.id.to_s,
        "X-TEST-SESSION-PUBLIC-ID" => token_record.public_id,
        "Authorization" => "Bearer #{access_token}",
        "Cookie" => "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}",
        "HTTP_COOKIE" => "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}",
      )
  end

  def authentication_harness_session_token(resource, session_public_id:)
    token = authentication_harness_token_model(resource).find_by(public_id: session_public_id) if session_public_id.present?
    token || authentication_harness_latest_token(resource) || authentication_harness_create_token(resource)
  end

  def authentication_harness_latest_token(resource)
    authentication_harness_token_model(resource)
      .where(authentication_harness_token_owner_column(resource) => resource.id)
      .where("discarded_at > ?", Time.current)
      .order(created_at: :desc)
      .first
  end

  def authentication_harness_create_token(resource)
    case resource
    when Client
      ClientToken.create!(
        user_id: resource.id,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
        user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
      )
    when Operator
      OperatorToken.create!(
        staff_id: resource.id,
        staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        staff_token_status_id: OperatorTokenStatus::ACTIVE,
        staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
        staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
      )
    when Visitor
      VisitorToken.create!(
        visitor_id: resource.id,
        visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        visitor_token_status_id: VisitorTokenStatus::ACTIVE,
        visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
        visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
      )
    else
      raise ArgumentError, "unsupported authenticated resource: #{resource.class.name}"
    end
  end

  def authentication_harness_token_model(resource)
    case resource
    when Client then ClientToken
    when Operator then OperatorToken
    when Visitor then VisitorToken
    else
      raise ArgumentError, "unsupported authenticated resource: #{resource.class.name}"
    end
  end

  def authentication_harness_token_owner_column(resource)
    case resource
    when Client then :user_id
    when Operator then :staff_id
    when Visitor then :visitor_id
    else
      raise ArgumentError, "unsupported authenticated resource: #{resource.class.name}"
    end
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end

    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = (normalized.include?("base") || normalized.include?("www.")) ? "BASE" : "SIGN"
    surface =
      if resource_type == "operator" || normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif resource_type == "visitor" || normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end

module ActiveSupport
  class TestCase
    include AuthenticationHarness

    parallel_workers =
      if ENV["COVERAGE"] == "true"
        1
      else
        Integer(ENV.fetch("PARALLEL_WORKERS", "16"), 10)
      end
    raise ArgumentError, "PARALLEL_WORKERS must be positive" unless parallel_workers.positive?

    fixtures :all
    ParallelTestDatabaseCloner.install!(workers: parallel_workers)
    parallelize(workers: parallel_workers, parallelize_databases: false)

    # The rate_limit backing store (config.x.rate_limit.store) is a single
    # MemoryStore instance created once at boot and shared by every test in the
    # process. Its counters are keyed by request IP (127.0.0.1 for all tests),
    # so without a reset a rate_limit test's counter leaks into later, unrelated
    # tests and spuriously 429s them. Clear it before each test for a clean slate
    # (mutate the same instance with #clear -- replacing it would not reach
    # controllers that captured the original store at class-load time).
    setup { Rails.configuration.x.rate_limit.fetch(:store).clear }
  end
end
