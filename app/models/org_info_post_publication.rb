# typed: false
# frozen_string_literal: true

class OrgInfoPostPublication < OrgPrincipalRecord
  self.table_name = "org_info_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "OrgInfoPost", version_class_name: "OrgInfoPostVersion"
end
