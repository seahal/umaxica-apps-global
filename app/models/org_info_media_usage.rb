# typed: false
# frozen_string_literal: true

class OrgInfoMediaUsage < OrgPrincipalRecord
  self.table_name = "org_info_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "OrgInfoMediaFile", post_class_name: "OrgInfoPost",
                        revision_class_name: "OrgInfoPostRevision", version_class_name: "OrgInfoPostVersion"
end
