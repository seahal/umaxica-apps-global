# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: chronicle_visibility_contexts
# Database name: chronicle
#
#  id         :bigint           not null, primary key
#  code       :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_chronicle_visibility_contexts_on_code  (code) UNIQUE
#

require "test_helper"

class ChronicleVisibilityContextTest < ActiveSupport::TestCase
  test "valid with valid attributes" do
    context = ChronicleVisibilityContext.new(code: "test", name: "Test Context")

    assert_predicate context, :valid?
  end

  test "validates presence of code" do
    context = ChronicleVisibilityContext.new(name: "Test Context")

    assert_predicate context, :invalid?
    assert_not_empty context.errors[:code]
  end

  test "validates presence of name" do
    context = ChronicleVisibilityContext.new(code: "test")

    assert_predicate context, :invalid?
    assert_not_empty context.errors[:name]
  end

  test "has many chronicle_visibilities" do
    assert_equal :has_many, ChronicleVisibilityContext.reflect_on_association(:chronicle_visibilities).macro
  end
end
