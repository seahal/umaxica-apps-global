# typed: false
# frozen_string_literal: true

class AppNewsMediaUsage < AppPrincipalRecord
  self.table_name = "app_news_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "AppNewsMediaFile", post_class_name: "AppNewsPost",
                        revision_class_name: "AppNewsPostRevision", version_class_name: "AppNewsPostVersion"
end
