# typed: false
# frozen_string_literal: true

class ComNewsPostPublication < ComPrincipalRecord
  self.table_name = "com_news_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "ComNewsPost", version_class_name: "ComNewsPostVersion"
end
