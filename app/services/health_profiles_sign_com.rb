# typed: false
# frozen_string_literal: true

HealthProfilesSignCom = HealthProfilesBase.new(
  cache_key: "sign-com",
  surface_label: "sign com",
  record_classes: [
    ComPrincipalRecord,
    ComTicketRecord,
    ComSettingRecord,
  ],
)
