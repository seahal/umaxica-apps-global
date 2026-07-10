# typed: false
# frozen_string_literal: true

class AppInfoMediaUsage < AppPrincipalRecord
  self.table_name = "app_info_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "AppInfoMediaFile", post_class_name: "AppInfoPost",
                        revision_class_name: "AppInfoPostRevision", version_class_name: "AppInfoPostVersion"
end
