# typed: false
# frozen_string_literal: true

# Provide a sane default `@headers` for tests that expect it but don't set it.
ActiveSupport.on_load(:active_support_test_case) do
  setup do
    unless instance_variable_defined?(:@headers) && @headers.present?
      if instance_variable_defined?(:@user) && @user
        host = defined?(ENV) ? (ENV["ID_SERVICE_URL"] || "id.app.localhost") : "id.app.localhost"
        @headers = as_user_headers(@user, host: host)
      elsif instance_variable_defined?(:@staff) && @staff
        host = defined?(ENV) ? (ENV["ID_STAFF_URL"] || "id.org.localhost") : "id.org.localhost"
        @headers = as_staff_headers(@staff, host: host)
      end
    end
  end
end
