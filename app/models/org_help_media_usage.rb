# typed: false
# frozen_string_literal: true

class OrgHelpMediaUsage < OrgPrincipalRecord
  self.table_name = "org_help_media_usages"

  include Cms::MediaUsageModel

  cms_media_usage_model media_file_class_name: "OrgHelpMediaFile", post_class_name: "OrgHelpPost",
                        revision_class_name: "OrgHelpPostRevision", version_class_name: "OrgHelpPostVersion"
end
