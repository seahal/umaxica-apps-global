# frozen_string_literal: true

SimpleCov.load_profile "rails"
SimpleCov.command_name "Rails Tests"
SimpleCov.merge_timeout 3600
SimpleCov.cover "{app,lib}/**/*.rb"
SimpleCov.source_in_json false

SimpleCov.group "Services", "app/services"
SimpleCov.group "Values", "app/values"
SimpleCov.group "Forms", "app/forms"
SimpleCov.group "Policies", "app/policies"
SimpleCov.group "Subscribers", "app/subscribers"
SimpleCov.group "Validators", "app/validators"
SimpleCov.group "Errors", "app/errors"

SimpleCov.coverage :line do
  minimum 95
end

SimpleCov.coverage :branch do
  minimum 75
end

# The minimums above are suite-wide averages, so a file with no test at all can hide
# behind well-covered neighbours. Hold every file to a floor of its own.
SimpleCov.minimum_coverage_by_file line: 70

# `refuse_coverage_drop` is deliberately NOT set. It compares against
# `coverage/.last_run.json`, and when that file is missing SimpleCov treats the run as having
# no previous result and passes. CI checks out fresh, `coverage/` is gitignored, and the
# workflow uploads it as an artifact without ever restoring it - so the check would never
# fire while still reading as a guarantee. Enabling it means first restoring the previous
# run's `coverage/.last_run.json` in the workflow.
