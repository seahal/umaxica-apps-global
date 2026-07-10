# typed: false
# frozen_string_literal: true

class OrgNewsPostSlug < OrgPrincipalRecord
  self.table_name = "org_news_post_slugs"

  include Cms::PostSlugModel

  cms_post_slug_model post_class_name: "OrgNewsPost"
end
