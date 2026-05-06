# typed: false
# frozen_string_literal: true

require "test_helper"

module Main
  class SurfaceTest < ActiveSupport::TestCase
    RequestStub = Struct.new(:host, :env)

    test "detects app surface from app.localhost" do
      request = RequestStub.new("app.localhost", {})

      assert_equal :app, Core::Surface.detect(request)
    end

    test "detects org surface from org.localhost" do
      request = RequestStub.new("org.localhost", {})

      assert_equal :org, Core::Surface.detect(request)
    end

    test "detects com surface from com.localhost" do
      request = RequestStub.new("com.localhost", {})

      assert_equal :com, Core::Surface.detect(request)
    end

    test "falls back to com when host has no surface subdomain" do
      request = RequestStub.new("localhost", {})

      assert_equal :com, Core::Surface.detect(request)
    end

    test "current returns detected surface from request host" do
      request = RequestStub.new("org.localhost", {})

      assert_equal :org, Core::Surface.current(request)
    end
  end
end
