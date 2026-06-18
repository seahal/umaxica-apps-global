# frozen_string_literal: true

require Rails.root.join("app/services/csp_violation_report_intake").to_s
require Rails.root.join("app/subscribers/csp_violation_subscriber").to_s

Rails.event.subscribe(CspViolationSubscriber.new) do |event|
  event[:name] == CspViolationReportIntake::EVENT_NAME
end
