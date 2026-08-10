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

  # `:push` is suspended at delivery time rather than at enqueue time, matching
  # OutboundEmailSuspensionInterceptor: notifications already queued when an
  # operator flips the switch must not reach APNs/FCM either. A suspended run is
  # a successful run -- raising here would burn the gem's retry budget on a
  # condition no retry can clear, and the notification is dropped rather than
  # replayed later.
  def perform(notification_class, notification_attributes, device)
    if OutboundChannelSuspension.suspended?(:push)
      Rails.logger.warn(
        JitLogEvent.format(
          "outbound.push.suspended",
          channel: "push",
          notification_class: notification_class.to_s,
        ),
      )
      return
    end

    super
  end
end
