# typed: false
# frozen_string_literal: true

module CspViolationReport
  extend ActiveSupport::Concern

  class_methods do
    def protect_csp_violation_report_intake
      rate_limit(to: 120, within: 1.minute, only: :create) if respond_to?(:rate_limit)
      rescue_from(ActionController::TooManyRequests, with: :ignore_rate_limited_csp_report)
    end
  end

  private

  def record_csp_violation!
    return if csp_report_body_too_large?

    CspViolationReportIntake.call(
      raw_body: bounded_csp_report_body,
      host: request.host,
      user_agent: request.user_agent,
    )
  end

  def ignore_malformed_csp_report
    head :no_content
  end

  def ignore_rate_limited_csp_report
    head :no_content
  end

  def csp_report_body_too_large?
    content_length = request.content_length
    content_length.present? && content_length > CspViolationReportIntake::MAX_BODY_BYTES
  end

  def bounded_csp_report_body
    request.body.read(CspViolationReportIntake::MAX_BODY_BYTES + 1)
  end
end
