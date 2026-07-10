# typed: false
# frozen_string_literal: true

class AppNewsPostPublication < AppPrincipalRecord
  self.table_name = "app_news_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "AppNewsPost", version_class_name: "AppNewsPostVersion"
end
