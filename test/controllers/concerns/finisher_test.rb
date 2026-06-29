# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class FinisherTest < ActiveSupport::TestCase
  class DummyController < ApplicationController
    include ::Finisher
  end

  test "dummy controller includes finisher" do
    assert_includes DummyController.ancestors, ::Finisher
  end

  test "finish_request does not hide subclass errors" do
    controller = DummyController.new

    controller.define_singleton_method(:finish_request) do
      raise RuntimeError, "finish failed"
    end

    assert_raises(RuntimeError) { controller.send(:finish_request) }
  end

  test "purge_current clears the actor context" do
    controller = DummyController.new

    Actor.stub(:clear, nil) do
      assert_nothing_raised { controller.send(:purge_current) }
    end
  end
end
