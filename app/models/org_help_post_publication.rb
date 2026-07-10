# typed: false
# frozen_string_literal: true

class OrgHelpPostPublication < OrgPrincipalRecord
  self.table_name = "org_help_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "OrgHelpPost", version_class_name: "OrgHelpPostVersion"
end
