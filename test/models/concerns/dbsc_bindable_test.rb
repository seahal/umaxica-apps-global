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

  test "dbsc status predicates use model constants" do
    status_class = Class.new
    status_class.const_set(:NOTHING, 0)
    status_class.const_set(:ACTIVE, 1)
    status_class.const_set(:PENDING, 2)
    status_class.const_set(:FAILED, 3)
    status_class.const_set(:REVOKE, 4)

    model_class =
      Class.new do
        include DbscBindable

        define_singleton_method(:attribute_names) do
          %w(binding_method_id dbsc_status_id)
        end

        define_method(:initialize) do |attributes|
          @attributes = attributes
        end

        delegate :[], to: :@attributes
      end

    model_class.define_singleton_method(:dbsc_status_class) { status_class }
    record = model_class.new(binding_method_id: 0, dbsc_status_id: status_class::ACTIVE)

    assert_predicate record, :dbsc_status_active?
    assert_not_predicate record, :dbsc_status_pending?
  end
end
