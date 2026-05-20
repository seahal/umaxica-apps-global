# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class OrgSettingRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :org_setting, reading: :org_setting_replica }
end
