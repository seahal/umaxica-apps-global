# typed: false
# frozen_string_literal: true

require "test_helper"

class Actor::ConfigurationTest < ActiveSupport::TestCase
  fixtures_none!

  test "bracket access uses fetch to access values" do
    config = Actor::Configuration.new(foo: "bar", baz: 42)

    assert_equal "bar", config[:foo]
    assert_equal 42, config[:baz]
    assert_equal Actor::Configuration::NULL_VALUE, config[:missing]
  end

  test "respond_to_missing returns true for any method" do
    config = Actor::Configuration.new(foo: "bar")

    assert_respond_to config, :foo
    assert_respond_to config, :anything
    assert_respond_to config, :some_random_method
  end

  test "hash consistency with equality" do
    config1 = Actor::Configuration.new(foo: "bar", baz: 42)
    config2 = Actor::Configuration.new(foo: "bar", baz: 42)
    config3 = Actor::Configuration.new(foo: "different")

    assert_equal config1, config2
    assert_equal config1.hash, config2.hash
    assert_not_equal config1, config3
    assert_not_equal config1.hash, config3.hash
  end

  test "null value responds to any message" do
    null = Actor::Configuration::NullValue.new

    assert_respond_to null, :anything
    assert_respond_to null, :some_method
    assert_respond_to null, :bogus
  end

  test "null value responds to all predicates" do
    null = Actor::Configuration::NULL_VALUE

    assert_nil null
    assert_predicate null, :blank?
    assert_not_predicate null, :present?
    assert_empty null.to_a
    assert_empty null.to_h
    assert_equal "", null.to_s
  end
end
