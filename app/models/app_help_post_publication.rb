# typed: false
# frozen_string_literal: true

class AppHelpPostPublication < AppPrincipalRecord
  self.table_name = "app_help_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "AppHelpPost", version_class_name: "AppHelpPostVersion"
end
