# typed: false
# frozen_string_literal: true

require "test_helper"

module Main
  class SurfaceTest < ActiveSupport::TestCase
    RequestStub = Struct.new(:host, :env)

    test "detects app surface from app.localhost" do
      request = RequestStub.new("app.localhost", {})

      assert_equal :app, CoreSurface.detect(request)
    end

    test "detects org surface from org.localhost" do
      request = RequestStub.new("org.localhost", {})

      assert_equal :org, CoreSurface.detect(request)
    end

    test "detects com surface from com.localhost" do
      request = RequestStub.new("com.localhost", {})

      assert_equal :com, CoreSurface.detect(request)
    end

    test "detects net surface from net.localhost" do
      request = RequestStub.new("net.localhost", {})

      assert_equal :net, CoreSurface.detect(request)
    end

    test "detects dev surface from dev.localhost" do
      request = RequestStub.new("dev.localhost", {})

      assert_equal :dev, CoreSurface.detect(request)
    end

    test "falls back to com when host has no surface subdomain" do
      request = RequestStub.new("localhost", {})

      assert_equal :com, CoreSurface.detect(request)
    end

    test "current returns detected surface from request host" do
      request = RequestStub.new("org.localhost", {})

      assert_equal :org, CoreSurface.current(request)
    end
  end
end
