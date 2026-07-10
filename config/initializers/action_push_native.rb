# frozen_string_literal: true

ActiveSupport.on_load(:action_push_native_record) do
  ActionPushNative::Record.connects_to(
    database: { writing: :com_zenith, reading: :com_zenith_replica },
  )
end
