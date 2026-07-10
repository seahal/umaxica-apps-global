# typed: false
# frozen_string_literal: true

class AppDocsMediaUsage < AppPrincipalRecord
  self.table_name = "app_docs_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "AppDocsMediaFile", post_class_name: "AppDocsPost",
                        revision_class_name: "AppDocsPostRevision", version_class_name: "AppDocsPostVersion"
end
