# typed: false
# frozen_string_literal: true

module CspViolationReport
  extend ActiveSupport::Concern

  included do
    rate_limit to: 120, within: 1.minute, only: :create if respond_to?(:rate_limit)
  end

  private

  def record_csp_violation!
    CspViolationReportIntake.call(
      raw_body: request.body.read,
      host: request.host,
      user_agent: request.user_agent,
    )
  end

  def ignore_malformed_csp_report
    head :no_content
  end
end
