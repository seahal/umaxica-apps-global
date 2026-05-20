# typed: false
# frozen_string_literal: true

require "action_push_native"
require "active_job"
require "active_model"
require File.join(
  Gem.loaded_specs.fetch("action_push_native").full_gem_path,
  "lib/action_push_native/notification.rb",
)

class ApplicationPushNotification < ActionPushNative::Notification
  # Set a custom job queue_name
  # queue_as :realtime

  # Controls whether push notifications are enabled.
  # self.enabled = Rails.env.production?

  # Define a custom callback to modify or abort the notification before it is sent
  # before_delivery do |notification|
  #   throw :abort if Notification.find(notification.context[:notification_id]).expired?
  # end
end
