# typed: false
# frozen_string_literal: true

class OrgDocsMediaFile < OrgPrincipalRecord
  self.table_name = "org_docs_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "OrgDocsMediaUsage"
end
