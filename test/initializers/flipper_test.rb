# typed: false
# frozen_string_literal: true

require "test_helper"

class FlipperInitializerTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "uses the in-memory adapter so the suite needs no Valkey instance" do
    adapter = Flipper.adapter
    adapter = adapter.adapter while adapter.respond_to?(:adapter)

    assert_kind_of Flipper::Adapters::Memory, adapter
  end

  test "features default to disabled and follow enable and disable" do
    feature = :flipper_initializer_test_feature

    assert_not Flipper.enabled?(feature)

    Flipper.enable(feature)

    assert Flipper.enabled?(feature)

    Flipper.disable(feature)

    assert_not Flipper.enabled?(feature)
  ensure
    Flipper.remove(feature)
  end
end
