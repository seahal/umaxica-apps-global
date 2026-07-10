# typed: false
# frozen_string_literal: true

class AppDocsMediaFile < AppPrincipalRecord
  self.table_name = "app_docs_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "AppDocsMediaUsage"
end
