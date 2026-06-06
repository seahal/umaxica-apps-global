# typed: false
# frozen_string_literal: true

HealthProfilesOrg = HealthProfilesBase.new(
  cache_key: "acme-org",
  surface_label: "org",
  record_classes: [
    OrgRpRecord,
    OrgSettingRecord,
    OrgSignalRecord,
  ],
)
