# typed: false
# frozen_string_literal: true

module Health
  module Profiles
    Org = Base.new(
      cache_key: "acme-org",
      surface_label: "org",
      record_classes: [
        OrgRpRecord,
        OrgSettingRecord,
        OrgSignalRecord,
      ],
    )
  end
end
