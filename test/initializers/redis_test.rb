# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedisInitializerTest < ActiveSupport::TestCase
  INITIALIZER_PATH = Rails.root.join("config/initializers/redis.rb")

  test "connection failure log does not include Redis URL credentials" do
    logged = []
    redis_client = Class.new do
      def ping
        raise Redis::CannotConnectError, "connection refused"
      end
    end.new
    env = ActiveSupport::StringInquirer.new("development")

    with_env(
      "REDIS_NORMAL_URL" => "rediss://:secret_credential@example.test/0",
      "REDIS_SMOKE_TEST" => "1",
      "REDIS_FAIL_FAST" => "0",
    ) do
      with_reloaded_redis_client do
        Redis.stub(:new, redis_client) do
          Rails.stub(:env, env) do
            Rails.logger.stub(:error, ->(message) { logged << message.to_s }) do
              load INITIALIZER_PATH
            end
          end
        end
      end
    end

    message = logged.join("\n")

    assert_includes message, "Redis connection failed"
    assert_no_match(/secret_credential/, message)
    assert_no_match(/:\/\/[^\/\s]*@/, message)
    assert_no_match(/:secret_credential@/, message)
  end

  test "development redis connection failure raises by default" do
    redis_client = Class.new do
      def ping
        raise Redis::CannotConnectError, "connection refused"
      end
    end.new
    env = ActiveSupport::StringInquirer.new("development")

    with_env(
      "REDIS_NORMAL_URL" => "redis://localhost:6379/0",
      "REDIS_SMOKE_TEST" => nil,
      "REDIS_FAIL_FAST" => nil,
    ) do
      with_reloaded_redis_client do
        Redis.stub(:new, redis_client) do
          Rails.stub(:env, env) do
            Rails.logger.stub(:error, ->(_message) { }) do
              assert_raises(Redis::CannotConnectError) { load INITIALIZER_PATH }
            end
          end
        end
      end
    end
  end

  test "rake tasks skip redis smoke tests during environment boot" do
    redis_client = Class.new do
      def ping
        flunk("redis ping should not run during rake tasks")
      end
    end.new
    env = ActiveSupport::StringInquirer.new("development")

    with_env(
      "REDIS_NORMAL_URL" => "redis://localhost:6379/0",
      "REDIS_SMOKE_TEST" => "1",
      "REDIS_FAIL_FAST" => "1",
    ) do
      with_reloaded_redis_client do
        Redis.stub(:new, redis_client) do
          Rails.stub(:env, env) do
            rake = Struct.new(:application).new(Struct.new(:top_level_tasks).new(["db:migrate:reset"]))
            stub_const(:Rake, rake) do
              Rails.logger.stub(:error, ->(_message) { flunk("redis errors should not be logged") }) do
                load INITIALIZER_PATH
              end
            end
          end
        end
      end
    end

    assert Object.const_defined?(:REDIS_CLIENT, false)
  end

  private

  def with_reloaded_redis_client
    previous = Object.const_get(:REDIS_CLIENT) if Object.const_defined?(:REDIS_CLIENT, false)
    Object.send(:remove_const, :REDIS_CLIENT) if Object.const_defined?(:REDIS_CLIENT, false)
    yield
  ensure
    Object.send(:remove_const, :REDIS_CLIENT) if Object.const_defined?(:REDIS_CLIENT, false)
    Object.const_set(:REDIS_CLIENT, previous) if defined?(previous)
  end

  def with_env(vars)
    old_values = vars.to_h { |key, _| [key, ENV[key]] }
    vars.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    old_values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  def stub_const(name, value)
    existed = Object.const_defined?(name, false)
    old_value = Object.const_get(name) if existed
    Object.const_set(name, value)
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    Object.const_set(name, old_value) if existed
  end
end
