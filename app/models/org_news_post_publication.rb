# typed: false
# frozen_string_literal: true

class OrgNewsPostPublication < OrgPrincipalRecord
  self.table_name = "org_news_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "OrgNewsPost", version_class_name: "OrgNewsPostVersion"
end
