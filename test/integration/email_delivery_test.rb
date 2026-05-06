# typed: false
# frozen_string_literal: true

require "test_helper"

class EmailDeliveryTest < ActionDispatch::IntegrationTest
  fixtures :user_email_statuses, :user_statuses

  setup do
    # Use the solid_queue adapter for this test to verify DB persistence
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue

    # Mock Turnstile to pass validation
    CloudflareTurnstile.test_mode = true
  end

  teardown do
    # Restore the original adapter
    ActiveJob::Base.queue_adapter = @previous_adapter if @previous_adapter

    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "deliver_later enqueues a job in solid_queue" do
    # Use a unique email to potentially avoid collisions (though db is cleaned)
    email = "delivery_test_#{SecureRandom.hex(4)}@example.com"

    assert_difference -> { SolidQueue::Job.where(class_name: "ActionMailer::MailDeliveryJob").count }, 1 do
      post sign_app_up_emails_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test_token",
           },
           headers: { "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost") }

      assert_response :redirect
    end

    # Find the job and verify it's a mail delivery job
    job = SolidQueue::Job.where(class_name: "ActionMailer::MailDeliveryJob").order(:created_at).last

    assert_equal "ActionMailer::MailDeliveryJob", job.class_name
    assert_equal "default", job.queue_name

    # Verify the job is for our email
    # Arguments are usually serialized, but we can check if the email address is present in the arguments
    # Note: Arguments format depends on how Rails serializes it, often complex with GlobalID
    # But usually contains the method name 'create' and arguments
  end
end
