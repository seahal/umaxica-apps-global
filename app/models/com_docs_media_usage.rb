# typed: false
# frozen_string_literal: true

class ComDocsMediaUsage < ComPrincipalRecord
  self.table_name = "com_docs_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "ComDocsMediaFile", post_class_name: "ComDocsPost",
                        revision_class_name: "ComDocsPostRevision", version_class_name: "ComDocsPostVersion"
end
