# frozen_string_literal: true

SimpleCov.load_profile "rails"
SimpleCov.cover "{app,lib}/**/*.rb"

SimpleCov.group "Services", "app/services"
SimpleCov.group "Values", "app/values"
SimpleCov.group "Forms", "app/forms"
SimpleCov.group "Policies", "app/policies"
SimpleCov.group "Subscribers", "app/subscribers"
SimpleCov.group "Validators", "app/validators"
SimpleCov.group "Errors", "app/errors"

SimpleCov.coverage :line do
  minimum 91
end

SimpleCov.coverage :branch
