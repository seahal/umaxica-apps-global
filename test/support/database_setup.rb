# typed: false
# frozen_string_literal: true

# Manual database initialization for test environment.
# These values are often expected to exist by various tests.

ActiveSupport.on_load(:active_record) do
  Prosopite.pause do
    if defined?(UserChronicleEvent)
      UserChronicleEvent.ensure_defaults!
    end

    if defined?(UserChronicleLevel)
      UserChronicleLevel.ensure_defaults!
    end

    if defined?(StaffChronicleLevel)
      StaffChronicleLevel.insert_missing_fixed_ids!([StaffChronicleLevel::NOTHING])
    end

    if defined?(StaffChronicleEvent)
      StaffChronicleEvent.ensure_defaults!
    end

    if defined?(AppPreferenceChronicleLevel)
      AppPreferenceChronicleLevel.ensure_defaults!
    end
    if defined?(AppPreferenceChronicleEvent)
      AppPreferenceChronicleEvent.ensure_defaults!
    end

    if defined?(ComPreferenceChronicleLevel)
      ComPreferenceChronicleLevel.ensure_defaults!
    end
    if defined?(ComPreferenceChronicleEvent)
      ComPreferenceChronicleEvent.ensure_defaults!
    end

    if defined?(OrgPreferenceChronicleLevel)
      OrgPreferenceChronicleLevel.ensure_defaults!
    end
    if defined?(OrgPreferenceChronicleEvent)
      OrgPreferenceChronicleEvent.ensure_defaults!
    end
  end
end
