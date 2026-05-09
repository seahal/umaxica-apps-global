# typed: false
# frozen_string_literal: true

# Manual database initialization for test environment.
# These values are often expected to exist by various tests.

ActiveSupport.on_load(:active_record) do
  next if ENV["SKIP_DB"] == "1" || defined?(@_test_reference_data_initialized)

  @_test_reference_data_initialized = true

  initializer =
    lambda do
      {
        "UserChronicleEvent" => -> { UserChronicleEvent },
        "UserChronicleLevel" => -> { UserChronicleLevel },
        "StaffChronicleEvent" => -> { StaffChronicleEvent },
        "AppPreferenceChronicleLevel" => -> { AppPreferenceChronicleLevel },
        "AppPreferenceChronicleEvent" => -> { AppPreferenceChronicleEvent },
        "ComPreferenceChronicleLevel" => -> { ComPreferenceChronicleLevel },
        "ComPreferenceChronicleEvent" => -> { ComPreferenceChronicleEvent },
        "OrgPreferenceChronicleLevel" => -> { OrgPreferenceChronicleLevel },
        "OrgPreferenceChronicleEvent" => -> { OrgPreferenceChronicleEvent },
      }.each do |constant_name, resolver|
        next unless Object.const_defined?(constant_name)

        resolver.call.ensure_defaults!
      end

      StaffChronicleLevel.insert_missing_fixed_ids!([StaffChronicleLevel::NOTHING]) if defined?(StaffChronicleLevel)
    end

  if defined?(Prosopite)
    Prosopite.pause(&initializer)
  else
    initializer.call
  end
end
