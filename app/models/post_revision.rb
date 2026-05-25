# typed: false
# frozen_string_literal: true

class PostRevision < AppPostRevision
  belongs_to :post, class_name: "Post", inverse_of: :post_revisions
  has_one :latest_post,
          class_name: "Post",
          foreign_key: :latest_revision_id,
          dependent: :nullify,
          inverse_of: :latest_revision_record
end

