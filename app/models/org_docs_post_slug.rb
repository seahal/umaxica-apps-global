# typed: false
# frozen_string_literal: true

class OrgDocsPostSlug < OrgPrincipalRecord
  self.table_name = "org_docs_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "OrgDocsPost"
end
