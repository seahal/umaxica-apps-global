# typed: false
# frozen_string_literal: true

require "test_helper"

class TaxonomyBuilderTest < ActiveSupport::TestCase
  class TaxonomyTestModel < OperatorRecord
    include Treeable

    def self.tree_root_parent_value = 0

    belongs_to :parent, class_name: "TaxonomyBuilderTest::TaxonomyTestModel", optional: true
    has_many :children, class_name: "TaxonomyBuilderTest::TaxonomyTestModel", foreign_key: :parent_id,
                        dependent: :destroy
  end

  def setup
    super
    @connection = OperatorRecord.connection
    @connection.create_table(:taxonomy_test_models, force: true) do |t|
      t.bigint(:parent_id)
      t.timestamps
    end
    TaxonomyTestModel.reset_column_information
  end

  def teardown
    @connection.drop_table(:taxonomy_test_models, if_exists: true)
    super
  end

  test "build returns a tree structure" do
    # Create a simple tree
    # 0 (sentinel) -> 1 (root) -> 2, 3
    # 3 -> 4
    root = TaxonomyTestModel.create!(id: 1, parent_id: 0)
    child1 = TaxonomyTestModel.create!(id: 2, parent_id: 1)
    child2 = TaxonomyTestModel.create!(id: 3, parent_id: 1)
    grandchild = TaxonomyTestModel.create!(id: 4, parent_id: 3)

    tree = TaxonomyBuilder.build(TaxonomyTestModel)

    assert_kind_of Array, tree
    assert_equal 1, tree.size
    assert_equal root.id, tree.first[:id]

    children = tree.first[:children]

    assert_equal 2, children.size
    assert_includes children.pluck(:id), child1.id
    assert_includes children.pluck(:id), child2.id

    child2_node = children.find { |c| c[:id] == child2.id }

    assert_equal 1, child2_node[:children].size
    assert_equal grandchild.id, child2_node[:children].first[:id]
  end

  test "records_from_model returns subtree when root exists" do
    # Create the sentinel record so it is found as root_id
    TaxonomyTestModel.insert_all([{ id: 0, parent_id: 0 }])

    TaxonomyTestModel.create!(id: 1, parent_id: 0)
    TaxonomyTestModel.create!(id: 2, parent_id: 1)

    records = TaxonomyBuilder.records_from_model(TaxonomyTestModel)

    assert_equal 2, records.count # 1 and 2
    # Wait, if root_id is 0, subtree_in_tree_order(0, include_self: false) returns descendants of 0.
    # Descendants of 0 are 1 and 2.
    assert_includes records.map(&:id), 1
    assert_includes records.map(&:id), 2
  end

  test "records_from_model returns all when root does not exist" do
    TaxonomyTestModel.create!(id: 100, parent_id: 99) # 0 sentinel doesn't exist as record

    records = TaxonomyBuilder.records_from_model(TaxonomyTestModel)

    assert_equal 1, records.count
    assert_equal 100, records.first.id
  end
end
