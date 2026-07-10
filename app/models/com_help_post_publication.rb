# typed: false
# frozen_string_literal: true

class ComHelpPostPublication < ComPrincipalRecord
  self.table_name = "com_help_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "ComHelpPost", version_class_name: "ComHelpPostVersion"
end
