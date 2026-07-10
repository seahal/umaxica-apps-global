# typed: false
# frozen_string_literal: true

class OrgInfoPostSlug < OrgPrincipalRecord
  self.table_name = "org_info_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "OrgInfoPost"
end
