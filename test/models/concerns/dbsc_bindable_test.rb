# typed: false
# frozen_string_literal: true

require "test_helper"

class DbscBindableTest < ActiveSupport::TestCase
  class MissingDbscModel
    include DbscBindable

    def self.attribute_names = []
  end

  class TestDbscModel
    include DbscBindable

    def self.attribute_names = %w(binding_method_id dbsc_status_id)

    def initialize(attributes)
      @attributes = attributes
    end

    delegate :[], to: :@attributes
  end

  test "raises when binding method attribute is missing" do
    assert_raises(NoMethodError) { MissingDbscModel.dbsc_binding_method_attribute_name }
  end

  test "raises when dbsc status attribute is missing" do
    assert_raises(NoMethodError) { MissingDbscModel.dbsc_status_attribute_name }
  end

  test "nothing predicates read resolved attributes" do
    record = TestDbscModel.new(binding_method_id: 0, dbsc_status_id: 0)

    assert_predicate record, :binding_method_nothing?
    assert_predicate record, :dbsc_status_nothing?
  end
end
