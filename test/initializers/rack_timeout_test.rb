# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class RackTimeoutInitializerTest < ActiveSupport::TestCase
  INITIALIZER_PATH = Rails.root.join("config/initializers/rack_timeout.rb")

  setup do
    @original_timeout = ENV["RACK_TIMEOUT_SERVICE_TIMEOUT"]
  end

  teardown do
    restore_timeout_env
  end

  test "defaults service timeout to 10 seconds" do
    ENV.delete("RACK_TIMEOUT_SERVICE_TIMEOUT")

    reload_initializer_with_non_test_env

    assert_equal "10", ENV["RACK_TIMEOUT_SERVICE_TIMEOUT"]
  end

  test "preserves an explicit service timeout" do
    ENV["RACK_TIMEOUT_SERVICE_TIMEOUT"] = "7"

    reload_initializer_with_non_test_env

    assert_equal "7", ENV["RACK_TIMEOUT_SERVICE_TIMEOUT"]
  end

  private

  def reload_initializer_with_non_test_env
    define_rack_timeout_stub

    Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
      load(INITIALIZER_PATH)
    end
  end

  def define_rack_timeout_stub
    return if defined?(Rack::Timeout)

    Rack.const_set(:Timeout, Module.new)
    logger_class = Class.new

    def logger_class.level
      @level
    end

    def logger_class.level=(value)
      @level = value
    end

    Rack::Timeout.const_set(:Logger, logger_class)
    @rack_timeout_stubbed = true
  end

  def restore_timeout_env
    if @rack_timeout_stubbed && Rack.const_defined?(:Timeout)
      Rack.send(:remove_const, :Timeout)
    end

    @original_timeout.nil? ? ENV.delete("RACK_TIMEOUT_SERVICE_TIMEOUT") : ENV["RACK_TIMEOUT_SERVICE_TIMEOUT"] =
                                                                            @original_timeout
  end
end
