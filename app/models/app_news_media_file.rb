# typed: false
# frozen_string_literal: true

class AppNewsMediaFile < AppPrincipalRecord
  self.table_name = "app_news_media_files"

  include Cms::MediaFileModel

  cms_media_file_model media_usage_class_name: "AppNewsMediaUsage"
end
