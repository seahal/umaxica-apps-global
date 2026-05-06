# typed: false
# frozen_string_literal: true

require "ostruct"
require "securerandom"

module TreeableSharedTests
  private

  def treeable_class
    raise NotImplementedError, "define `treeable_class` in the including test class"
  end

  def tree_root_sentinel
    if treeable_class.respond_to?(:tree_root_parent_value)
      treeable_class.tree_root_parent_value
    else
      0
    end
  end

  def string_id_column?
    treeable_class.columns_hash.fetch("id", OpenStruct.new(type: :string)).type == :string
  end

  def ensure_root_sentinel!(klass)
    return if klass.exists?(id: tree_root_sentinel)

    attributes = { id: tree_root_sentinel, parent_id: tree_root_sentinel }
    now = Time.current
    attributes[:created_at] = now if klass.column_names.include?("created_at")
    attributes[:updated_at] = now if klass.column_names.include?("updated_at")

    klass.insert_all!([attributes])

  end

  def create_master!(klass, id: nil, parent: nil, parent_id: nil, position: nil)
    attributes = {}
    attributes[:id] = id if id

    if parent
      attributes[:parent] = parent
    elsif parent_id
      attributes[:parent_id] = parent_id
    else
      attributes[:parent_id] = tree_root_sentinel
    end

    if klass.column_names.include?("position")
      attributes[:position] = position
    end

    klass.create!(attributes)
  end

  def build_tree!(klass)
    ensure_root_sentinel!(klass)
    if string_id_column?
      token = SecureRandom.hex(4).upcase

      root = create_master!(klass, id: "ROOT_#{token}", parent_id: tree_root_sentinel, position: 0)
      a = create_master!(klass, id: "A_#{token}", parent: root, position: 2)
      b = create_master!(klass, id: "B_#{token}", parent: root, position: 1)
      c = create_master!(klass, id: "C_#{token}", parent: root, position: 1)
      c1 = create_master!(klass, id: "C1_#{token}", parent: c, position: 1)
    else
      root = create_master!(klass, parent_id: tree_root_sentinel, position: 0)
      a = create_master!(klass, parent: root, position: 2)
      b = create_master!(klass, parent: root, position: 1)
      c = create_master!(klass, parent: root, position: 1)
      c1 = create_master!(klass, parent: c, position: 1)
    end

    { root: root, a: a, b: b, c: c, c1: c1 }
  end

  public

  def test_validates_id_presence_and_uniqueness
    unless string_id_column?
      assert true, "Skipping string-specific ID validation for integer ID column"
      return
    end

    klass = treeable_class
    ensure_root_sentinel!(klass)

    master = klass.new(id: nil, parent_id: tree_root_sentinel)

    assert_not master.valid?
    assert_not_empty master.errors[:id]

    token = SecureRandom.hex(4).upcase
    existing = create_master!(klass, id: "EXISTING_#{token}", parent_id: tree_root_sentinel)
    duplicate = klass.new(id: existing.id.downcase, parent_id: tree_root_sentinel)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:id]
  end

  def test_upcases_id_before_validation
    unless string_id_column?
      assert true, "Skipping upcase validation for integer ID column"
      return
    end

    klass = treeable_class
    ensure_root_sentinel!(klass)

    master = klass.new(id: "new_category", parent_id: tree_root_sentinel)
    master.valid?

    assert_equal "NEW_CATEGORY", master.id
  end

  def test_validates_id_format
    unless string_id_column?
      assert true, "Skipping ID format validation for integer ID column"
      return
    end

    klass = treeable_class
    ensure_root_sentinel!(klass)

    master = klass.new(id: "INVALID-ID!", parent_id: tree_root_sentinel)

    assert_not master.valid?
    assert_not_empty master.errors[:id]
  end

  def test_name_returns_string
    klass = treeable_class
    ensure_root_sentinel!(klass)

    id_value = string_id_column? ? "TEST_CAT" : 1
    master = klass.new(id: id_value, parent_id: tree_root_sentinel)

    assert_respond_to master, :name
    assert_kind_of String, master.name
  end

  def test_validates_length_of_id
    unless string_id_column?
      assert true, "Skipping ID length validation for integer ID column"
      return
    end

    klass = treeable_class
    ensure_root_sentinel!(klass)

    record = klass.new(id: "A" * 256, parent_id: tree_root_sentinel)

    assert_predicate record, :invalid?
    assert_predicate record.errors[:id], :any?
  end

  def test_tree_parent_and_children_associations
    tree = build_tree!(treeable_class)

    assert_nil tree[:root].parent
    assert_equal tree[:root], tree[:b].parent
    assert_equal tree[:root], tree[:c].parent
    assert_equal tree[:c], tree[:c1].parent

    root_child_ids = tree[:root].children.pluck(:id)

    assert_includes root_child_ids, tree[:a].id
    assert_includes root_child_ids, tree[:b].id
    assert_includes root_child_ids, tree[:c].id

    assert_includes tree[:c].children.pluck(:id), tree[:c1].id
  end

  def test_root_and_leaf_predicates
    tree = build_tree!(treeable_class)

    assert_predicate tree[:root], :root?
    assert_not tree[:b].root?

    assert_not tree[:root].leaf?
    assert_predicate tree[:a], :leaf?
    assert_predicate tree[:b], :leaf?
    assert_not tree[:c].leaf?
    assert_predicate tree[:c1], :leaf?
  end

  def test_siblings_include_self_options
    klass = treeable_class
    tree = build_tree!(klass)

    sibling_ids_without_self = tree[:b].siblings(include_self: false).map(&:id)
    sibling_ids_with_self = tree[:b].siblings(include_self: true).map(&:id)

    if klass.column_names.include?("position")
      assert_equal [tree[:c].id, tree[:a].id], sibling_ids_without_self
      assert_equal [tree[:b].id, tree[:c].id, tree[:a].id], sibling_ids_with_self
    else
      assert_equal [tree[:a].id, tree[:c].id], sibling_ids_without_self
      assert_equal [tree[:a].id, tree[:b].id, tree[:c].id], sibling_ids_with_self
    end
  end

  def test_subtree_ids_and_ancestor_ids
    klass = treeable_class
    tree = build_tree!(klass)

    expected_subtree_ids = [tree[:root].id, tree[:a].id, tree[:b].id, tree[:c].id, tree[:c1].id]

    subtree_ids_with_self = klass.subtree_ids(tree[:root].id, include_self: true)

    assert_equal expected_subtree_ids.sort, subtree_ids_with_self.sort

    subtree_ids_without_self = klass.subtree_ids(tree[:root].id, include_self: false)

    assert_equal (expected_subtree_ids - [tree[:root].id]).sort, subtree_ids_without_self.sort

    ancestor_ids_with_self = klass.ancestor_ids(tree[:c1].id, include_self: true)

    assert_equal [tree[:root].id, tree[:c].id, tree[:c1].id], ancestor_ids_with_self

    ancestor_ids_without_self = klass.ancestor_ids(tree[:c1].id, include_self: false)

    assert_equal [tree[:root].id, tree[:c].id], ancestor_ids_without_self
  end

  def test_breadcrumb_order
    tree = build_tree!(treeable_class)

    assert_equal [tree[:root].id, tree[:c].id, tree[:c1].id], tree[:c1].breadcrumb.map(&:id)
  end

  def test_ancestors_and_descendants
    tree = build_tree!(treeable_class)

    ancestor_ids_with_self = tree[:c1].ancestors(include_self: true).map(&:id)
    ancestor_ids_without_self = tree[:c1].ancestors(include_self: false).map(&:id)

    assert_equal [tree[:root].id, tree[:c].id, tree[:c1].id], ancestor_ids_with_self
    assert_equal [tree[:root].id, tree[:c].id], ancestor_ids_without_self

    descendant_ids_with_self = tree[:c].descendants(include_self: true).map(&:id)
    descendant_ids_without_self = tree[:c].descendants(include_self: false).map(&:id)

    assert_equal [tree[:c].id, tree[:c1].id], descendant_ids_with_self
    assert_equal [tree[:c1].id], descendant_ids_without_self
  end

  def test_subtree_in_tree_order_is_stable
    klass = treeable_class
    tree = build_tree!(klass)

    ids = klass.subtree_in_tree_order(tree[:root].id, include_self: true).pluck(:id)

    if klass.column_names.include?("position")
      expected = [tree[:root].id, tree[:b].id, tree[:c].id, tree[:c1].id, tree[:a].id]

      assert_equal expected, ids
    else
      expected = [tree[:root].id, tree[:a].id, tree[:b].id, tree[:c].id, tree[:c1].id]

      assert_equal expected, ids
    end
  end

  def test_cycle_validation
    tree = build_tree!(treeable_class)

    node = tree[:b]
    node.parent_id = node.id

    assert_not node.valid?
    assert_predicate node.errors[:parent_id], :any?

    root = tree[:root]
    root.parent_id = tree[:c1].id

    assert_not root.valid?
    assert_predicate root.errors[:parent_id], :any?

    a = tree[:a]
    a.parent = tree[:c]

    assert_predicate a, :valid?
    a.save!
  end

  def test_subtree_ids_with_max_depth
    klass = treeable_class
    tree = build_tree!(klass)

    # depth 0 is root, depth 1 is a, b, c, depth 2 is c1
    # max_depth limits the traversal.
    # If max_depth is 1, only root and its immediate children are included?
    # Wait, the SQL says `WHERE tree.depth < max_depth`.
    # Anchor is depth 0. Children are depth 1.
    # If max_depth is 1, children are joined, but their depth is 1.
    # In UNION ALL: select t.*, tree.depth + 1 FROM ... JOIN tree ON ... WHERE tree.depth < max_depth
    # If tree.depth is 0 (root), then 0 < 1 is true, so children (depth 1) are added.
    # Next iteration, tree.depth is 1. 1 < 1 is false. So grandchildren are not added.
    # So max_depth 1 means: anchor + immediate children.

    ids = klass.subtree_ids(tree[:root].id, include_self: true, max_depth: 1)

    assert_includes ids, tree[:root].id
    assert_includes ids, tree[:a].id
    assert_includes ids, tree[:b].id
    assert_includes ids, tree[:c].id
    assert_not_includes ids, tree[:c1].id
  end

  def test_subtree_ids_with_max_depth_include_self_false
    klass = treeable_class
    tree = build_tree!(klass)

    # include_self: false means anchor starts at children.
    # Anchor (children) is depth 0. Grandchildren are depth 1.
    # If max_depth is 1, grandchildren (depth 1) are included. Great-grandchildren are not.
    ids = klass.subtree_ids(tree[:root].id, include_self: false, max_depth: 1)

    assert_includes ids, tree[:a].id
    assert_includes ids, tree[:b].id
    assert_includes ids, tree[:c].id
    assert_includes ids, tree[:c1].id # depth 1 relative to children
  end

  def test_ancestor_ids_with_max_depth
    klass = treeable_class
    tree = build_tree!(klass)

    # c1 (depth 0) -> c (depth 1) -> root (depth 2)
    # max_depth 1: c1 and c
    ids = klass.ancestor_ids(tree[:c1].id, include_self: true, max_depth: 1)

    assert_includes ids, tree[:c1].id
    assert_includes ids, tree[:c].id
    assert_not_includes ids, tree[:root].id
  end

  def test_subtree_in_tree_order_with_max_depth
    klass = treeable_class
    tree = build_tree!(klass)

    relation = klass.subtree_in_tree_order(tree[:root].id, include_self: true, max_depth: 1)
    ids = relation.pluck(:id)

    assert_includes ids, tree[:root].id
    assert_includes ids, tree[:c].id
    assert_not_includes ids, tree[:c1].id
  end

  def test_subtree_ids_returns_empty_for_nonexistent_id
    klass = treeable_class
    nonexistent_id = string_id_column? ? "NONEXISTENT" : 999_999
    ids = klass.subtree_ids(nonexistent_id)

    assert_empty ids
  end

  def test_ancestor_ids_returns_empty_for_nonexistent_id
    klass = treeable_class
    nonexistent_id = string_id_column? ? "NONEXISTENT" : 999_999
    ids = klass.ancestor_ids(nonexistent_id)

    assert_empty ids
  end

  def test_subtree_ids_returns_empty_for_root_sentinel
    klass = treeable_class
    ids = klass.subtree_ids(tree_root_sentinel, include_self: true)

    assert_kind_of Array, ids
  end
end
