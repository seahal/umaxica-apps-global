# typed: false
# frozen_string_literal: true

class ComDocsPostPublication < ComPrincipalRecord
  self.table_name = "com_docs_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "ComDocsPost", version_class_name: "ComDocsPostVersion"
end
