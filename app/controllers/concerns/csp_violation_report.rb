# typed: false
# frozen_string_literal: true

module CspViolationReport
  extend ActiveSupport::Concern

  private

  def record_csp_violation!
    report = JSON.parse(request.body.read)
    payload = report["csp-report"] || {}

    Rails.logger.info(Jit::LogEvent.format("security.csp_violation", **payload.symbolize_keys))
  rescue JSON::ParserError
    nil
  end

  def ignore_malformed_csp_report
    head :no_content
  end
end
