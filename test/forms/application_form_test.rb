# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class ApplicationFormTest < ActiveSupport::TestCase
  class TestForm < ApplicationForm
    attribute :name
    attribute :email

    validates :name, presence: true
    validates :email, presence: true
  end

  test "persisted? returns false" do
    form = TestForm.new

    assert_not form.persisted?
  end

  test "attributes can be set" do
    form = TestForm.new(name: "John", email: "john@example.com")

    assert_equal "John", form.name
    assert_equal "john@example.com", form.email
  end

  test "validations work" do
    form = TestForm.new

    assert_not form.valid?
    assert_predicate form.errors.full_messages, :any?
  end

  test "valid form is valid" do
    form = TestForm.new(name: "John", email: "john@example.com")

    assert_predicate form, :valid?
  end
end
