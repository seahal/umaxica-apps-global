# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationPushNotificationJobTest < ActiveJob::TestCase
  test "ApplicationPushNotificationJob inherits from ActionPushNative::NotificationJob" do
    assert_equal "ActionPushNative::NotificationJob", ApplicationPushNotificationJob.superclass.name
  end

  test "job can be instantiated" do
    job = ApplicationPushNotificationJob.new

    assert_instance_of ApplicationPushNotificationJob, job
  end

  test "job queue_name method exists" do
    assert_respond_to ApplicationPushNotificationJob, :queue_name
  end

  test "job has log_arguments disabled by default" do
    assert_not ApplicationPushNotificationJob.log_arguments
  end

  test "job has report_job_retries disabled by default" do
    assert_not ApplicationPushNotificationJob.report_job_retries
  end

  test "job can be performed with notification class and device" do
    notification_class = "ApplicationPushNotification"
    notification_attributes = { title: "Test", body: "Message" }
    device = nil

    assert_nothing_raised do
      ApplicationPushNotificationJob.perform_now(notification_class, notification_attributes, device)
    end
  end
end
