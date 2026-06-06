# typed: false
# frozen_string_literal: true

module Health
  module Profiles
    SignCom = Base.new(
      cache_key: "sign-com",
      surface_label: "sign com",
      record_classes: [
        ComPrincipalRecord,
        ComTicketRecord,
        ComSettingRecord,
      ],
    )
  end
end
