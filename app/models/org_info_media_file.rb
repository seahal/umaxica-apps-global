# typed: false
# frozen_string_literal: true

class OrgInfoMediaFile < OrgPrincipalRecord
  self.table_name = "org_info_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "OrgInfoMediaUsage"
end
