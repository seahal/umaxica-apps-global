# typed: false
# frozen_string_literal: true

class AppHelpMediaUsage < AppPrincipalRecord
  self.table_name = "app_help_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "AppHelpMediaFile", post_class_name: "AppHelpPost",
                        revision_class_name: "AppHelpPostRevision", version_class_name: "AppHelpPostVersion"
end
