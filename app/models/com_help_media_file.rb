# typed: false
# frozen_string_literal: true

class ComHelpMediaFile < ComPrincipalRecord
  self.table_name = "com_help_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "ComHelpMediaUsage"
end
