# frozen_string_literal: true

require "json"
require "uri"

class CspViolationReportIntake
  MAX_BODY_BYTES = 64.kilobytes
  MAX_STRING_LENGTH = 256
  EVENT_NAME = "security.csp_violation"

  URL_FIELDS = %w(
    blocked-uri
    document-uri
    referrer
    source-file
  ).freeze

  DIRECTIVE_FIELDS = %w(
    disposition
    effective-directive
    violated-directive
  ).freeze

  NUMERIC_FIELDS = %w(
    column-number
    line-number
    status-code
  ).freeze

  EXTENSION_SCHEMES = %w(
    chrome-extension
    edge-extension
    extension
    moz-extension
    safari-extension
  ).freeze

  Result = Data.define(:status, :reports_count)

  def self.call(...) = new(...).call

  def initialize(raw_body:, host:, user_agent: nil, logger: Rails.logger)
    @raw_body = raw_body.to_s
    @host = host.to_s
    @user_agent = user_agent.to_s.presence
    @logger = logger
  end

  def call
    return Result.new(status: :too_large, reports_count: 0) if raw_body.bytesize > MAX_BODY_BYTES

    report_objects = parse_report_objects
    report_objects.each { |report| log_report(report) }

    Result.new(status: :accepted, reports_count: report_objects.size)
  rescue JSON::ParserError
    Result.new(status: :malformed, reports_count: 0)
  end

  private

  attr_reader :raw_body, :host, :user_agent, :logger

  def parse_report_objects
    normalize_reports(JSON.parse(raw_body)).filter_map { |report| sanitize_report(report) }
  end

  def normalize_reports(parsed)
    case parsed
    when Array
      parsed.filter_map { |entry| reporting_api_body(entry) }
    when Hash
      [legacy_report_body(parsed)]
    else
      []
    end
  end

  def reporting_api_body(entry)
    return unless entry.is_a?(Hash)
    return unless entry["type"].blank? || entry["type"] == "csp-violation"

    body = entry["body"]
    body if body.is_a?(Hash)
  end

  def legacy_report_body(entry)
    body = entry["csp-report"]
    return body if body.is_a?(Hash)

    entry
  end

  def sanitize_report(report)
    sanitized = {}

    URL_FIELDS.each do |field|
      sanitized[underscore(field)] = sanitize_url(report[field]) if report.key?(field)
    end

    DIRECTIVE_FIELDS.each do |field|
      sanitized[underscore(field)] = sanitize_string(report[field]) if report.key?(field)
    end

    NUMERIC_FIELDS.each do |field|
      sanitized[underscore(field)] = sanitize_integer(report[field]) if report.key?(field)
    end

    sanitized.compact!
    return if sanitized.blank?

    category = report_category(sanitized)
    sanitized.merge(
      category: category,
      aggregation_key: aggregation_key(sanitized, category),
      host: host,
      user_agent_family: user_agent_family,
    ).compact
  end

  def log_report(report)
    logger.info(JitLogEvent.format(EVENT_NAME, report))
  end

  def sanitize_url(value)
    sanitized = sanitize_string(value)
    return if sanitized.blank?

    uri = URI.parse(sanitized)
    uri.query = nil
    uri.fragment = nil
    uri.to_s
  rescue URI::InvalidURIError
    sanitized.split(/[?#]/, 2).first
  end

  def sanitize_string(value)
    return unless value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(Numeric)

    value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").first(MAX_STRING_LENGTH)
  end

  def sanitize_integer(value)
    Integer(value, exception: false)
  end

  def report_category(report)
    urls = report.values_at(:blocked_uri, :source_file, :document_uri).compact
    return "browser_extension" if urls.any? { |url| extension_url?(url) }

    "application"
  end

  def extension_url?(url)
    uri = URI.parse(url)
    EXTENSION_SCHEMES.include?(uri.scheme)
  rescue URI::InvalidURIError
    EXTENSION_SCHEMES.any? { |scheme| url.start_with?("#{scheme}:") }
  end

  def aggregation_key(report, category)
    directive = report[:effective_directive] || report[:violated_directive] || "unknown"
    blocked = origin_or_scheme(report[:blocked_uri]) || "unknown"

    "#{category}:#{directive}:#{blocked}"
  end

  def origin_or_scheme(url)
    return if url.blank?

    uri = URI.parse(url)
    return uri.scheme if EXTENSION_SCHEMES.include?(uri.scheme)
    return uri.scheme if uri.host.blank?

    "#{uri.scheme}://#{uri.host}"
  rescue URI::InvalidURIError
    "invalid"
  end

  def user_agent_family
    return if user_agent.blank?

    sanitize_string(user_agent.split.first)
  end

  def underscore(value)
    value.tr("-", "_").to_sym
  end
end
