# typed: false
# frozen_string_literal: true

HealthProfilesSignOrg = HealthProfilesBase.new(
  cache_key: "sign-org",
  surface_label: "sign org",
  record_classes: [
    OrgPrincipalRecord,
    OrgTicketRecord,
    OrgSettingRecord,
  ],
)
