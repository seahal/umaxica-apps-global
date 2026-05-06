# typed: false
# frozen_string_literal: true

require "test_helper"

class SlugIdTest < ActiveSupport::TestCase
  class SlugIdTestModel < OperatorRecord
    include SlugId
    # slug_id column is required by the concern
  end

  def setup
    super
    @connection = OperatorRecord.connection
    @connection.create_table(:slug_id_test_models, force: true) do |t|
      t.string(:slug_id, limit: 32)
      t.timestamps
    end
    SlugIdTestModel.reset_column_information
  end

  def teardown
    @connection.drop_table(:slug_id_test_models, if_exists: true)
    super
  end

  test "generates slug_id on create" do
    record = SlugIdTestModel.create!

    assert_predicate record.slug_id, :present?
    assert_equal 32, record.slug_id.length
    assert_match(/\A[a-z0-9-]+\z/, record.slug_id)
  end

  test "does not override provided slug_id" do
    custom_slug = "custom-slug-123"
    record = SlugIdTestModel.create!(slug_id: custom_slug)

    assert_equal custom_slug, record.slug_id
  end

  test "validates slug_id format" do
    record = SlugIdTestModel.new(slug_id: "INVALID_SLUG!")

    assert_not record.valid?
    assert_predicate record.errors[:slug_id], :any?
  end

  test "validates slug_id length" do
    record = SlugIdTestModel.new(slug_id: "a" * 33)

    assert_not record.valid?
    assert_predicate record.errors[:slug_id], :any?
  end
end
