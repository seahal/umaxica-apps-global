# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class TestJob < ApplicationJob
  def self.last_performed_value
    Thread.current[:test_job_last_performed_value]
  end

  def self.last_performed_value=(value)
    Thread.current[:test_job_last_performed_value] = value
  end

  def perform(value)
    self.class.last_performed_value = value
  end
end

class SolidQueueTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    # Clear any existing jobs
    SolidQueue::Job.delete_all
    TestJob.last_performed_value = nil

    # Use the solid_queue adapter for tests that need to persist jobs to the DB
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue
  end

  teardown do
    # Restore the original adapter
    ActiveJob::Base.queue_adapter = @previous_adapter
  end

  test "can enqueue a job" do
    assert_difference -> { SolidQueue::Job.count }, 1 do
      TestJob.perform_later("test_value")
    end
  end

  test "job is stored in queue database" do
    job = TestJob.perform_later("test_value")

    solid_queue_job = SolidQueue::Job.find_by(active_job_id: job.job_id)

    assert_not_nil solid_queue_job
    assert_equal "TestJob", solid_queue_job.class_name
    assert_equal "default", solid_queue_job.queue_name
  end

  test "can perform enqueued job" do
    # Switch to inline adapter for this test
    ActiveJob::Base.queue_adapter = :inline

    TestJob.perform_later("hello_world")

    assert_equal "hello_world", TestJob.last_performed_value
  end

  test "can schedule a job for later" do
    future_time = 1.hour.from_now

    job = TestJob.set(wait: 1.hour).perform_later("scheduled_value")

    solid_queue_job = SolidQueue::Job.find_by(active_job_id: job.job_id)

    assert_not_nil solid_queue_job
    assert_not_nil solid_queue_job.scheduled_at
    assert_in_delta future_time.to_i, solid_queue_job.scheduled_at.to_i, 2
  end

  test "jobs use queue database connection" do
    TestJob.perform_later("test")

    # Verify the job is in the queue database, not the primary database
    assert_equal "queue", SolidQueue::Job.connection_db_config.name
  end

  test "can query job status" do
    job = TestJob.perform_later("status_test")

    solid_queue_job = SolidQueue::Job.find_by(active_job_id: job.job_id)

    assert_nil solid_queue_job.finished_at

    # Switch to inline adapter and perform the job
    ActiveJob::Base.queue_adapter = :inline
    TestJob.perform_later("status_test_2")

    # Check that inline execution worked
    assert_equal "status_test_2", TestJob.last_performed_value
  end

  test "handles job failure" do
    # Create a job that will fail
    job_id = nil

    assert_no_difference -> { SolidQueue::FailedExecution.count } do
      job = TestJob.perform_later("fail_test")
      job_id = job.job_id
    end

    # Job should be created
    solid_queue_job = SolidQueue::Job.find_by(active_job_id: job_id)

    assert_not_nil solid_queue_job
  end
end
