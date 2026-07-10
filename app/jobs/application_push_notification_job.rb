# typed: false
# frozen_string_literal: true

require "action_push_native"
require "active_job"
require File.join(
  Gem.loaded_specs.fetch("action_push_native").full_gem_path,
  "app/jobs/action_push_native/notification_job.rb",
)

class ApplicationPushNotificationJob < ActionPushNative::NotificationJob
  # Enable logging job arguments (default: false)
  # self.log_arguments = true

  # Report job retries via the `Rails.error` reporter (default: false)
  # self.report_job_retries = true
end
