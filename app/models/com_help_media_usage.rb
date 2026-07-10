# typed: false
# frozen_string_literal: true

class ComHelpMediaUsage < ComPrincipalRecord
  self.table_name = "com_help_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "ComHelpMediaFile", post_class_name: "ComHelpPost",
                        revision_class_name: "ComHelpPostRevision", version_class_name: "ComHelpPostVersion"
end
