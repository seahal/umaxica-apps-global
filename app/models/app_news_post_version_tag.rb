# typed: false
# frozen_string_literal: true

class AppNewsPostVersionTag < AppPrincipalRecord
  self.table_name = "app_news_post_version_tags"

  include Cms::TagAssignmentModel

  cms_tag_assignment_model owner_name: :post_version, owner_class_name: "AppNewsPostVersion",
                           owner_foreign_key: :post_version_id, owner_inverse: :version_tags, tag_class_name: "AppNewsTag"
end
