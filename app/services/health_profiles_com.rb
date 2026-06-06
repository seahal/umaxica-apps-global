# typed: false
# frozen_string_literal: true

HealthProfilesCom = HealthProfilesBase.new(
  cache_key: "acme-com",
  surface_label: "com",
  record_classes: [
    ComRpRecord,
    ComSettingRecord,
    ComSignalRecord,
  ],
)
