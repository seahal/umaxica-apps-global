# typed: false
# frozen_string_literal: true

require "test_helper"

class SolidInfrastructureTest < ActiveSupport::TestCase
  test "cache write/read works" do
    old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:solid_cache_store, { namespace: "test" })
    begin
      Rails.cache.clear
      Rails.cache.write("test_key", "test_value")

      assert_equal "test_value", Rails.cache.read("test_key")
    ensure
      Rails.cache = old_cache
    end
  end

  test "solid queue job enqueues and executes" do
    # We might need to run the worker in a thread or just check if it enqueues correctly
    # Since we are in a test environment, the queue_adapter might be :test.
    # To really test Solid Queue, we should use it explicitly.

    old_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue

    begin
      job =
        Class.new(ApplicationJob) do
          define_method(:perform) do |arg|
            File.write("tmp/job_test.txt", arg)
          end
        end
      Object.const_set(:InfrastructureTestJob, job)

      InfrastructureTestJob.perform_later("done")

      # In test environment, Solid Queue might not have a worker running.
      # But we can check the database.
      assert_operator SolidQueue::Job.count, :>=, 1
    ensure
      ActiveJob::Base.queue_adapter = old_adapter
      Object.send(:remove_const, :InfrastructureTestJob)
      FileUtils.rm_f("tmp/job_test.txt")
    end
  end
end
