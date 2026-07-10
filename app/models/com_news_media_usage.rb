# typed: false
# frozen_string_literal: true

class ComNewsMediaUsage < ComPrincipalRecord
  self.table_name = "com_news_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "ComNewsMediaFile", post_class_name: "ComNewsPost",
                        revision_class_name: "ComNewsPostRevision", version_class_name: "ComNewsPostVersion"
end
