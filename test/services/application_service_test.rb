# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationServiceTest < ActiveSupport::TestCase
  class TestService < ApplicationService
    attr_reader :value

    def initialize(value:)
      super
      @value = value
    end

    def call
      @value * 2
    end
  end

  class FailingService < ApplicationService
    def call
      raise NotImplementedError, "test error"
    end
  end

  test ".call invokes new and call" do
    result = TestService.call(value: 21)

    assert_equal 42, result
  end

  test "#call raises NotImplementedError when not overridden" do
    assert_raises(NotImplementedError) do
      ApplicationService.new.call
    end
  end

  test "#initialize accepts arbitrary arguments as a no-op default" do
    service = ApplicationService.new(:anything, keyword: "value")

    assert_instance_of ApplicationService, service
  end
end
