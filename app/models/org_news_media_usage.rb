# typed: false
# frozen_string_literal: true

class OrgNewsMediaUsage < OrgPrincipalRecord
  self.table_name = "org_news_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "OrgNewsMediaFile", post_class_name: "OrgNewsPost",
                        revision_class_name: "OrgNewsPostRevision", version_class_name: "OrgNewsPostVersion"
end
