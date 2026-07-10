# typed: false
# frozen_string_literal: true

class OrgNewsMediaFile < OrgPrincipalRecord
  self.table_name = "org_news_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "OrgNewsMediaUsage"
end
