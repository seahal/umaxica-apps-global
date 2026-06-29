# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationJobTest < ActiveJob::TestCase
  class TestJob < ApplicationJob
    def perform(value)
      value
    end
  end

  class DeadlockedJob < ApplicationJob
    def perform
      raise ActiveRecord::Deadlocked
    end
  end

  class DeserializationJob < ApplicationJob
    def perform
      begin
        raise ArgumentError, "missing global id"
      rescue ArgumentError
        raise ActiveJob::DeserializationError
      end
    end
  end

  test "ApplicationJob is a subclass of ActiveJob::Base" do
    assert_kind_of ActiveJob::Base, ApplicationJob.new
  end

  test "jobs can be performed" do
    result = TestJob.new.perform("test_value")

    assert_equal "test_value", result
  end

  test "job class inherits from ApplicationJob" do
    assert_equal ApplicationJob, TestJob.superclass
  end

  test "job can be instantiated" do
    job = TestJob.new

    assert_instance_of TestJob, job
    assert_kind_of ApplicationJob, job
  end

  test "job class has queue adapter configured" do
    assert_not_nil TestJob.queue_adapter
  end

  test "deadlocked jobs are retried" do
    assert_enqueued_with(job: DeadlockedJob) do
      DeadlockedJob.perform_now
    end
  end

  test "deserialization errors are discarded" do
    assert_no_enqueued_jobs do
      DeserializationJob.perform_now
    end
  end
end
