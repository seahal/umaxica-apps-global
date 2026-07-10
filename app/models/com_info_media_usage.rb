# typed: false
# frozen_string_literal: true

class ComInfoMediaUsage < ComPrincipalRecord
  self.table_name = "com_info_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "ComInfoMediaFile", post_class_name: "ComInfoPost",
                        revision_class_name: "ComInfoPostRevision", version_class_name: "ComInfoPostVersion"
end
