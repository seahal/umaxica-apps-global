# typed: false
# frozen_string_literal: true

class OrgDocsPostPublication < OrgPrincipalRecord
  self.table_name = "org_docs_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "OrgDocsPost", version_class_name: "OrgDocsPostVersion"
end
