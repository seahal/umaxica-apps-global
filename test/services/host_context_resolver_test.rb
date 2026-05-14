# typed: false
# frozen_string_literal: true

require "test_helper"

class HostContextResolverTest < ActiveSupport::TestCase
  Request = Struct.new(:host)

  test "resolves app surface from host" do
    context = HostContextResolver.call(Request.new("www.app.localhost"))

    assert_equal :app, context.surface
    assert_nil context.account
    assert_nil context.tenant
  end

  test "resolves org surface from host" do
    context = HostContextResolver.call(Request.new("id.org.localhost"))

    assert_equal :org, context.surface
  end

  test "falls back through Core surface defaults" do
    context = HostContextResolver.call(Request.new("example.test"))

    assert_equal Core::Surface::DEFAULT, context.surface
  end
end
