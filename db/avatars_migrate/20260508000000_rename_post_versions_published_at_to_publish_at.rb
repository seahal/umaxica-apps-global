# frozen_string_literal: true

class RenamePostVersionsPublishedAtToPublishAt < ActiveRecord::Migration[8.2]
  def up
    return unless column_exists?(:post_versions, :published_at)
    return if column_exists?(:post_versions, :publish_at)

    rename_column(:post_versions, :published_at, :publish_at)
  end

  def down
    return unless column_exists?(:post_versions, :publish_at)
    return if column_exists?(:post_versions, :published_at)

    rename_column(:post_versions, :publish_at, :published_at)
  end
end
