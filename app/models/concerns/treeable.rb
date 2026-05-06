# typed: false
# frozen_string_literal: true

module Treeable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_tree_parent_id
    validate :tree_parent_must_not_create_cycle

    prepend InstanceMethods
  end

  module InstanceMethods
    def root?
      self.class.tree_root_parent_values.include?(tree_parent_id_raw)
    end

    def leaf?
      !children_exists?
    end

    def siblings(include_self: false)
      parent_col = tree_parent_column
      raw_parent = tree_parent_id_raw

      relation =
        self.class
          .where(parent_col => raw_parent)
          .then { |r| self.class.tree_order_scope(r) }

      include_self ? relation : relation.where.not(self.class.primary_key => id)
    end

    def ancestors(include_self: false)
      ids = self.class.ancestor_ids(id, include_self: include_self)
      self.class.tree_relation_in_ids_order(ids)
    end

    def descendants(include_self: false)
      self.class.subtree_in_tree_order(id, include_self: include_self)
    end

    def breadcrumb
      ancestors(include_self: true)
    end

    # When `parent_id` is a sentinel (e.g. "none"), the belongs_to association would
    # otherwise try to resolve a record with that id. Treat it as `nil` to avoid
    # mis-resolution and unnecessary queries.
    def parent
      return nil if self.class.tree_root_parent_values.include?(tree_parent_id_raw)

      super
    end

    private

    def children_exists?
      if respond_to?(:children)
        children.exists?
      else
        self.class.exists?(tree_parent_column => id)
      end
    end

    def tree_parent_id_raw
      self[tree_parent_column]
    end
  end

  class_methods do
    # Override by defining this in the model.
    def tree_parent_column = "parent_id"

    # Root sentinel value stored in the parent column.
    #
    def tree_root_parent_value = "none"

    # Accept multiple root sentinel values for compatibility across models/tables.
    # The default supports both "NOTHING" and "none" sentinels.
    def tree_root_parent_values
      base = [tree_root_parent_value]
      column_type = columns_hash.fetch(tree_parent_column, nil)&.type
      return (base + ["NOTHING", "none"]).uniq if column_type == :string

      values = base.select { |value| value.is_a?(Numeric) || value.to_s.match?(/\A-?\d+\z/) }
      values.uniq!
      values
    end

    # Sibling order: prefers `position` when present; otherwise uses `id`.
    def tree_order_column
      column_names.include?("position") ? "position" : nil
    end

    def tree_order_scope(relation)
      pk = primary_key
      order_col = tree_order_column

      if order_col
        relation.order(arel_table[order_col].asc.nulls_last, pk => :asc)
      else
        relation.order(pk => :asc)
      end
    end

    def tree_relation_in_ids_order(ids)
      return none if ids.blank?

      q_pk = connection.quote_column_name(primary_key)
      q_table = connection.quote_table_name(table_name)
      order_sql = sanitize_sql_array(["array_position(ARRAY[?]::text[], #{q_table}.#{q_pk}::text)", ids])

      where(primary_key => ids).order(Arel.sql(order_sql))
    end

    # Builds recursive CTE using Rails with_recursive API.
    # Returns a relation that can be chained with other ActiveRecord methods.
    def tree_recursive_cte(anchor_relation, direction: :descendants, max_depth: nil)
      table = arel_table
      tree = Arel::Table.new(:tree)

      join_condition =
        case direction
        when :descendants
          table[tree_parent_column].eq(tree[:id])
        when :ancestors
          table[primary_key].eq(tree[:parent_id])
        else
          raise ArgumentError, "unknown tree recursion direction: #{direction.inspect}"
        end

      anchor = anchor_relation.select(
        table[primary_key].as("id"),
        table[tree_parent_column].as("parent_id"),
        Arel.sql("0 AS depth"),
      )

      recursive = select(
        table[primary_key],
        table[tree_parent_column],
        Arel.sql("tree.depth + 1"),
      ).joins(table.join(tree).on(join_condition).join_sources)

      recursive = recursive.where(tree: { depth: ...Integer(max_depth) }) if max_depth

      # with_recursive is available on the relation
      unscoped.with_recursive(tree: [anchor, recursive])
    end

    # Descendant ids (including self).
    def subtree_ids(root_id, include_self: true, max_depth: nil)
      q_pk = connection.quote_column_name(primary_key)
      q_parent = connection.quote_column_name(tree_parent_column)
      q_table = connection.quote_table_name(table_name)
      root_vals = tree_root_parent_values

      if root_vals.include?(root_id)
        # Treat passing the sentinel as "roots"; including self in this case is ambiguous,
        # so behave like `include_self: false` and start from root nodes.
        include_self = false
      end

      where_anchor_sql = include_self ? "#{q_pk} = ?" : "#{q_parent} = ?"
      depth_guard = max_depth ? "WHERE tree.depth < #{Integer(max_depth)}" : ""

      # rubocop:disable I18n/RailsI18n/DecorateString
      sql_template = <<~SQL.squish
        WITH RECURSIVE tree AS (
          SELECT #{q_pk} AS id, #{q_parent} AS parent_id, 0 AS depth
          FROM #{q_table}
          WHERE (#{where_anchor_sql} AND #{q_pk} NOT IN (?))

          UNION ALL

          SELECT t.#{q_pk}, t.#{q_parent}, tree.depth + 1
          FROM #{q_table} t
          JOIN tree ON t.#{q_parent} = tree.id
          #{depth_guard}
        )
        SELECT id FROM tree;
      SQL

      sql = sanitize_sql_array([sql_template, root_id, root_vals])

      connection.exec_query(sql, "subtree_ids").rows.flatten
    end

    # Ancestor ids (including self).
    def ancestor_ids(node_id, include_self: true, max_depth: nil)
      q_pk = connection.quote_column_name(primary_key)
      q_parent = connection.quote_column_name(tree_parent_column)
      q_table = connection.quote_table_name(table_name)
      root_vals = tree_root_parent_values

      where_anchor_sql =
        if include_self
          "#{q_pk} = ?"
        else
          "#{q_pk} = (SELECT #{q_parent} FROM #{q_table} WHERE #{q_pk} = ?)"
        end

      depth_guard = max_depth ? " AND tree.depth < #{Integer(max_depth)}" : ""

      # rubocop:disable I18n/RailsI18n/DecorateString
      sql_template = <<~SQL.squish
        WITH RECURSIVE tree AS (
          SELECT #{q_pk} AS id, #{q_parent} AS parent_id, 0 AS depth
          FROM #{q_table}
          WHERE (#{where_anchor_sql} AND #{q_pk} NOT IN (?))

          UNION ALL

          SELECT p.#{q_pk}, p.#{q_parent}, tree.depth + 1
          FROM #{q_table} p
          JOIN tree ON tree.parent_id = p.#{q_pk}
          WHERE tree.parent_id NOT IN (?)#{depth_guard}
        )
        SELECT id FROM tree
        ORDER BY depth DESC;
      SQL

      sql = sanitize_sql_array([sql_template, node_id, root_vals, root_vals])

      connection.exec_query(sql, "ancestor_ids").rows.flatten
    end

    # Returns a subtree ordered "by tree order" (prefers `position`) as a Relation.
    #
    # - Builds `path` in the CTE and `ORDER BY path`
    # - Stores id as text in `path` (normalizes String/UUID/Integer)
    # - Stores position as integer in `path` (if missing, uses id only)
    # - Returns a Relation preserving the `ids` order
    def subtree_in_tree_order(root_id, include_self: true, max_depth: nil)
      q_pk = connection.quote_column_name(primary_key)
      q_parent = connection.quote_column_name(tree_parent_column)
      q_table = connection.quote_table_name(table_name)
      order_col = tree_order_column
      pk_type = columns_hash.fetch(primary_key, nil)&.type
      pk_sort_expr = pk_type.in?([:integer, :bigint]) ? "#{q_pk}::bigint" : "#{q_pk}::text"
      root_vals = tree_root_parent_values

      include_self = false if include_self && root_vals.include?(root_id)
      where_anchor_sql = include_self ? "#{q_pk} = ?" : "#{q_parent} = ?"
      depth_guard = max_depth ? "WHERE tree.depth < #{Integer(max_depth)}" : ""

      anchor_path =
        if order_col
          q_order = connection.quote_column_name(order_col)
          "ARRAY[ROW(#{q_order}::int, #{pk_sort_expr})]::record[]"
        else
          "ARRAY[ROW(#{pk_sort_expr})]::record[]"
        end

      step_path =
        if order_col
          q_order = connection.quote_column_name(order_col)
          "tree.path || ARRAY[ROW(t.#{q_order}::int, t.#{pk_sort_expr})]::record[]"
        else
          "tree.path || ARRAY[ROW(t.#{pk_sort_expr})]::record[]"
        end

      sql_template =

        # rubocop:disable I18n/RailsI18n/DecorateString
        <<~SQL.squish
            WITH RECURSIVE tree AS (
              SELECT
                #{q_table}.*,
                0 AS depth,
                #{anchor_path} AS path
              FROM #{q_table}
              WHERE (#{where_anchor_sql} AND #{q_pk} NOT IN (?))

            UNION ALL

            SELECT
              t.*,
              tree.depth + 1 AS depth,
              #{step_path} AS path
            FROM #{q_table} t
            JOIN tree ON t.#{q_parent} = tree.#{q_pk}
            #{depth_guard}
          )
          SELECT #{q_pk}
          FROM tree
          ORDER BY path;
        SQL
      sql = sanitize_sql_array([sql_template, root_id, root_vals])

      ids = connection.exec_query(sql, "subtree_in_tree_order_ids").rows.flatten

      # Preserve `ids` order using Postgres `array_position`.
      order_sql = sanitize_sql_array(["array_position(ARRAY[?]::text[], #{q_table}.#{q_pk}::text)", ids])
      where(primary_key => ids).order(Arel.sql(order_sql))
    end
  end

  # ---- instance side ----

  delegate :tree_parent_column, to: :class

  def normalize_tree_parent_id
    parent_col = tree_parent_column
    root_val = self.class.tree_root_parent_value
    raw = self[parent_col]

    # Normalize blank values to the configured sentinel.
    return if raw.present?

    self[parent_col] = root_val

  end

  def tree_parent_must_not_create_cycle
    parent_col = tree_parent_column
    pid = self[parent_col]
    root_vals = self.class.tree_root_parent_values

    return if pid.blank?
    return if root_vals.include?(pid)
    return if persisted? && !will_save_change_to_attribute?(parent_col)

    if persisted? && pid == id
      errors.add(parent_col, "cannot be self")
      return
    end

    # New records do not have an `id`, so cycle detection is not possible (self-check is enough).
    return unless persisted?

    # If parent is within this node's descendants, it creates a cycle.
    descendant_ids = self.class.subtree_ids(id, include_self: true)
    errors.add(parent_col, "cannot be a descendant (cycle detected)") if descendant_ids.include?(pid)
  end
end
