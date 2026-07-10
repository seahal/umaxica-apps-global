# typed: false
# frozen_string_literal: true

class ComDocsMediaFile < ComPrincipalRecord
  self.table_name = "com_docs_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "ComDocsMediaUsage"
end
