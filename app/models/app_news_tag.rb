# typed: false
# frozen_string_literal: true

class AppNewsTag < AppPrincipalRecord
  self.table_name = "app_news_tags"

  include Cms::TagModel

  cms_tag_model revision_assignment_class_name: "AppNewsPostRevisionTag",
                version_assignment_class_name: "AppNewsPostVersionTag"
end
