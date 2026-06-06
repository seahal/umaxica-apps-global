# typed: false
# frozen_string_literal: true

HealthProfilesSignApp = HealthProfilesBase.new(
  cache_key: "sign-app",
  surface_label: "sign app",
  record_classes: [
    AppPrincipalRecord,
    AppTicketRecord,
    AppSettingRecord,
  ],
)
