# typed: false
# frozen_string_literal: true

class OrgHelpMediaFile < OrgPrincipalRecord
  self.table_name = "org_help_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "OrgHelpMediaUsage"
end
