# typed: false
# frozen_string_literal: true

module Health
  module Profiles
    App = Base.new(
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
  end
end
