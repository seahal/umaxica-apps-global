# typed: false
# frozen_string_literal: true

class AppHelpMediaFile < AppPrincipalRecord
  self.table_name = "app_help_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "AppHelpMediaUsage"
end
