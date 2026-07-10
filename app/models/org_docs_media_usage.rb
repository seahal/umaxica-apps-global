# typed: false
# frozen_string_literal: true

class OrgDocsMediaUsage < OrgPrincipalRecord
  self.table_name = "org_docs_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "OrgDocsMediaFile", post_class_name: "OrgDocsPost",
                        revision_class_name: "OrgDocsPostRevision", version_class_name: "OrgDocsPostVersion"
end
