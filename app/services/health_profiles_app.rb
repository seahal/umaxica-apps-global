# typed: false
# frozen_string_literal: true

HealthProfilesApp = HealthProfilesBase.new(
  cache_key: "acme-app",
  surface_label: "app",
  record_classes: [
    AppRpRecord,
    AppSettingRecord,
    AppSignalRecord,
    AvatarRecord,
    OccurrenceRecord,
  ],
)
