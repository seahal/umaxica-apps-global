# typed: false
# frozen_string_literal: true

module Health
  module Profiles
    Com = Base.new(
      cache_key: "acme-com",
      surface_label: "com",
      record_classes: [
        ComRpRecord,
        ComSettingRecord,
        ComSignalRecord,
      ],
    )
  end
end
