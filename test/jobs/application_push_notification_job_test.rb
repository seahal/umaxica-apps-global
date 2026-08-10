# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationPushNotificationJobTest < ActiveJob::TestCase
  teardown { Flipper.disable(:outbound_push_suspended) }
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

  test "delivery is attempted while the push channel is running" do
    delivered_to = :not_called

    with_delivery_recorded_into(->(device) { delivered_to = device }) do
      ApplicationPushNotificationJob.perform_now("ApplicationPushNotification", { title: "T", body: "B" }, "device-1")
    end

    assert_equal "device-1", delivered_to
  end

  test "a suspended push channel is not delivered and is not an error" do
    Flipper.enable(:outbound_push_suspended)

    assert_nothing_raised do
      with_delivery_recorded_into(->(_device) { flunk("push was delivered while suspended") }) do
        ApplicationPushNotificationJob.perform_now("ApplicationPushNotification", { title: "T", body: "B" }, "device-1")
      end
    end
  end

  private

  # Replaces the gem's delivery with a recorder so the test observes whether the
  # external APNs/FCM call would have been made, without a real device record.
  def with_delivery_recorded_into(recorder)
    original = ActionPushNative::NotificationJob.instance_method(:perform)
    ActionPushNative::NotificationJob.define_method(:perform) do |_class_name, _attributes, device|
      recorder.call(device)
    end
    yield
  ensure
    ActionPushNative::NotificationJob.define_method(:perform, original)
  end
end
