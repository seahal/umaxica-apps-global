# typed: false
# frozen_string_literal: true

class ComInfoPostPublication < ComPrincipalRecord
  self.table_name = "com_info_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "ComInfoPost", version_class_name: "ComInfoPostVersion"
end
