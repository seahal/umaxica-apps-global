# frozen_string_literal: true

class RenameOrgPublisherPostTablesToModelConventions < ActiveRecord::Migration[8.2]
  TABLE_RENAMES = {
    post_statuses: :org_post_statuses,
    post_review_statuses: :org_post_review_statuses,
    post_category_masters: :org_post_category_masters,
    post_tag_masters: :org_post_tag_masters,
    posts: :org_posts,
    post_categories: :org_post_categories,
    post_tags: :org_post_tags,
    post_reviews: :org_post_reviews,
    post_versions: :org_post_versions,
    post_revisions: :org_post_revisions,
  }.freeze

  COLUMN_RENAMES = {
    org_posts: {
      post_status_id: :org_post_status_id,
      latest_version_id: :latest_org_post_version_id,
      latest_revision_id: :latest_org_post_revision_id,
    },
    org_post_categories: {
      post_id: :org_post_id,
      post_category_master_id: :org_post_category_master_id,
    },
    org_post_tags: {
      post_id: :org_post_id,
      post_tag_master_id: :org_post_tag_master_id,
    },
    org_post_reviews: {
      post_id: :org_post_id,
      post_review_status_id: :org_post_review_status_id,
    },
    org_post_versions: {
      post_id: :org_post_id,
    },
    org_post_revisions: {
      post_id: :org_post_id,
    },
  }.freeze

  INDEX_RENAMES = {
    org_posts: {
      index_posts_on_latest_revision_id: :index_org_posts_on_latest_org_post_revision_id,
      index_posts_on_latest_version_id: :index_org_posts_on_latest_org_post_version_id,
      index_posts_on_post_status_id: :index_org_posts_on_org_post_status_id,
      index_posts_on_author_avatar_id_and_created_at: :index_org_posts_on_author_avatar_id_and_created_at,
      index_posts_on_permalink: :index_org_posts_on_permalink,
      index_posts_on_public_id: :index_org_posts_on_public_id,
      index_posts_on_published_at_and_expires_at: :index_org_posts_on_published_at_and_expires_at,
    },
    org_post_categories: {
      index_post_categories_on_post_category_master_id: :index_org_post_categories_on_org_post_category_master_id,
      index_post_categories_on_post_id: :index_org_post_categories_on_org_post_id,
    },
    org_post_category_masters: {
      index_post_category_masters_on_parent_id: :index_org_post_category_masters_on_parent_id,
    },
    org_post_reviews: {
      index_post_reviews_on_post_id_and_reviewer_actor_id: :index_org_post_reviews_on_org_post_id_and_reviewer_actor_id,
      index_post_reviews_on_post_review_status_id: :index_org_post_reviews_on_org_post_review_status_id,
      index_post_reviews_on_reviewer_actor_id: :index_org_post_reviews_on_reviewer_actor_id,
    },
    org_post_revisions: {
      index_post_revisions_on_post_id_and_created_at: :index_org_post_revisions_on_org_post_id_and_created_at,
      index_post_revisions_on_public_id: :index_org_post_revisions_on_public_id,
    },
    org_post_tag_masters: {
      index_post_tag_masters_on_parent_id: :index_org_post_tag_masters_on_parent_id,
    },
    org_post_tags: {
      index_post_tags_on_post_id: :index_org_post_tags_on_org_post_id,
      index_post_tags_on_post_tag_master_id_and_post_id: :index_org_post_tags_on_org_post_tag_master_id_and_org_post_id,
    },
    org_post_versions: {
      index_post_versions_on_post_id_and_created_at: :index_org_post_versions_on_org_post_id_and_created_at,
      index_post_versions_on_public_id: :index_org_post_versions_on_public_id,
    },
  }.freeze

  CHECK_CONSTRAINT_RENAMES = {
    org_posts: {
      chk_posts_response_mode: :chk_org_posts_response_mode,
      chk_posts_redirect_url_for_redirect: :chk_org_posts_redirect_url_for_redirect,
    },
    org_post_versions: {
      chk_post_versions_response_mode: :chk_org_post_versions_response_mode,
      chk_post_versions_redirect_url_for_redirect: :chk_org_post_versions_redirect_url_for_redirect,
    },
    org_post_revisions: {
      chk_post_revisions_response_mode: :chk_org_post_revisions_response_mode,
      chk_post_revisions_redirect_url_for_redirect: :chk_org_post_revisions_redirect_url_for_redirect,
    },
    org_post_categories: {
      post_categories_master_id_non_negative: :org_post_categories_master_id_non_negative,
    },
    org_post_category_masters: {
      post_category_masters_parent_id_non_negative: :org_post_category_masters_parent_id_non_negative,
    },
    org_post_tags: {
      post_tags_master_id_non_negative: :org_post_tags_master_id_non_negative,
    },
    org_post_tag_masters: {
      post_tag_masters_parent_id_non_negative: :org_post_tag_masters_parent_id_non_negative,
    },
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict(old_table, new_table) }
    rename_columns(COLUMN_RENAMES)
    rename_indexes(INDEX_RENAMES)
    rename_check_constraints(CHECK_CONSTRAINT_RENAMES)
  end

  def down
    rename_check_constraints(reverse_nested(CHECK_CONSTRAINT_RENAMES))
    rename_indexes(reverse_nested(INDEX_RENAMES))
    rename_columns(reverse_nested(COLUMN_RENAMES))
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict(new_table, old_table) }
  end

  private

  def rename_columns(mapping)
    mapping.each do |table_name, columns|
      columns.each do |old_name, new_name|
        safety_assured { rename_column(table_name, old_name, new_name) }
      end
    end
  end

  def rename_indexes(mapping)
    mapping.each do |table_name, indexes|
      indexes.each do |old_name, new_name|
        rename_index_strict(table_name, old_name, new_name)
      end
    end
  end

  def rename_index_strict(table_name, old_name, new_name)
    return rename_index(table_name, old_name, new_name) if index_name_exists?(table_name, old_name)
    return if index_name_exists?(table_name, new_name)

    raise "Expected index #{old_name} or #{new_name} on #{table_name}"
  end

  def rename_check_constraints(mapping)
    mapping.each do |table_name, constraints|
      constraints.each do |old_name, new_name|
        rename_check_constraint(table_name, old_name, new_name)
      end
    end
  end

  def rename_check_constraint(table_name, old_name, new_name)
    constraint = check_constraints(table_name).find { |candidate| candidate.name == old_name.to_s }
    return unless constraint

    remove_check_constraint(table_name, name: old_name)
    add_check_constraint(table_name, constraint.expression, name: new_name, validate: false)
  end

  def reverse_nested(mapping)
    mapping.transform_values { |nested| nested.invert }
  end
end
