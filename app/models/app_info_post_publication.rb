# typed: false
# frozen_string_literal: true

class AppInfoPostPublication < AppPrincipalRecord
  self.table_name = "app_info_post_publications"

  include Cms::PostPublicationModel

  cms_post_publication_model post_class_name: "AppInfoPost", version_class_name: "AppInfoPostVersion"
end
