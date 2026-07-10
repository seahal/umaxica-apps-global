# typed: false
# frozen_string_literal: true

class AppDocsPostPublication < AppPrincipalRecord
  self.table_name = "app_docs_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "AppDocsPost", version_class_name: "AppDocsPostVersion"
end
