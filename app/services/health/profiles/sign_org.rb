# typed: false
# frozen_string_literal: true

module Health
  module Profiles
    SignOrg = Base.new(
      cache_key: "sign-org",
      surface_label: "sign org",
      record_classes: [
        OrgPrincipalRecord,
        OrgTicketRecord,
        OrgSettingRecord,
      ],
    )
  end
end
