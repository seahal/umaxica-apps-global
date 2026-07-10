# typed: false
# frozen_string_literal: true

class ComInfoMediaFile < ComPrincipalRecord
  self.table_name = "com_info_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "ComInfoMediaUsage"
end
