# typed: false
# frozen_string_literal: true

class OrgHelpPostSlug < OrgPrincipalRecord
  self.table_name = "org_help_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "OrgHelpPost"
end
