# typed: false
# frozen_string_literal: true

require "test_helper"

class TreeableTest < ActiveSupport::TestCase
  include TreeableSharedTests

  class TreeableTestModel < OperatorRecord
    include Treeable

    def self.tree_root_parent_value = 0

    # Associations normally defined in the model
    belongs_to :parent, class_name: "TreeableTest::TreeableTestModel", optional: true
    has_many :children, class_name: "TreeableTest::TreeableTestModel", foreign_key: :parent_id, dependent: :destroy

    def name
      "Node #{id}"
    end
  end

  class TreeableStringTestModel < OperatorRecord
    include Treeable

    # Associations normally defined in the model
    belongs_to :parent, class_name: "TreeableTest::TreeableStringTestModel", optional: true
    has_many :children, class_name: "TreeableTest::TreeableStringTestModel", foreign_key: :parent_id,
                        dependent: :destroy

    def name
      "Node #{id}"
    end
  end

  def setup
    super
    @connection = OperatorRecord.connection
    @connection.create_table(:treeable_test_models, force: true) do |t|
      t.bigint(:parent_id)
      t.integer(:position)
      t.timestamps
    end
    @connection.create_table(:treeable_string_test_models, id: false, force: true) do |t|
      t.string(:id, primary_key: true)
      t.string(:parent_id)
      t.integer(:position)
      t.timestamps
    end
    TreeableTestModel.reset_column_information
    TreeableStringTestModel.reset_column_information
  end

  def teardown
    @connection.drop_table(:treeable_test_models, if_exists: true)
    @connection.drop_table(:treeable_string_test_models, if_exists: true)
    super
  end

  test "tree_recursive_cte returns descendants" do
    tree = build_tree!(TreeableTestModel)
    relation = TreeableTestModel.tree_recursive_cte(
      TreeableTestModel.where(id: tree[:root].id),
      direction: :descendants,
    )

    ids = relation.pluck(:id)

    assert_includes ids, tree[:root].id
    assert_includes ids, tree[:a].id
    assert_includes ids, tree[:b].id
    assert_includes ids, tree[:c].id
    assert_includes ids, tree[:c1].id
  end

  test "tree_recursive_cte returns ancestors" do
    tree = build_tree!(TreeableTestModel)
    relation = TreeableTestModel.tree_recursive_cte(TreeableTestModel.where(id: tree[:c1].id), direction: :ancestors)

    ids = relation.pluck(:id)

    assert_includes ids, tree[:c1].id
    assert_includes ids, tree[:c].id
    assert_includes ids, tree[:root].id
  end

  test "tree_recursive_cte rejects unknown direction" do
    assert_raises(ArgumentError) do
      TreeableTestModel.tree_recursive_cte(TreeableTestModel.none, direction: :sideways)
    end
  end

  test "tree order scope falls back to primary key when position column is absent" do
    TreeableTestModel.stub(:tree_order_column, nil) do
      assert_match(/ORDER BY .*id.*ASC/i, TreeableTestModel.tree_order_scope(TreeableTestModel.all).to_sql)
    end
  end

  test "normalizes blank parent to root sentinel" do
    node = TreeableTestModel.new(parent_id: nil)

    node.normalize_tree_parent_id

    assert_equal 0, node.parent_id
  end

  test "leaf? falls back to class existence check without children association" do
    node = TreeableTestModel.create!(parent_id: 0)

    # We want to test the case where the model does not have a :children association.
    # stubbing respond_to? to return false for :children will force it to the fallback.
    node.stub(:respond_to?, ->(name, _include_all = false) { !(name == :children) }) do
      assert_predicate node, :leaf?
    end
  end

  test "works with string id column" do # rubocop:disable Minitest/NoAssertions
    # This will trigger the string-specific logic in Treeable
    @current_model = TreeableStringTestModel
    TreeableStringTestModel.transaction do
      test_subtree_ids_and_ancestor_ids
      test_tree_parent_and_children_associations
    end
  ensure
    @current_model = nil
  end

  private

  def treeable_class
    @current_model || TreeableTestModel
  end
end
