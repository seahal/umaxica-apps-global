# typed: false
# frozen_string_literal: true

module Health
  module Profiles
    SignApp = Base.new(
      cache_key: "sign-app",
      surface_label: "sign app",
      record_classes: [
        AppPrincipalRecord,
        AppTicketRecord,
        AppSettingRecord,
      ],
    )
  end
end
