# typed: false
# frozen_string_literal: true

class ComNewsMediaFile < ComPrincipalRecord
  self.table_name = "com_news_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "ComNewsMediaUsage"
end
