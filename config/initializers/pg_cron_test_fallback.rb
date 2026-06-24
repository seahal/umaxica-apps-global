# frozen_string_literal: true

return unless Rails.env.test?

ActiveSupport.on_load(:active_record_postgresqladapter) do
  module PgCronTestFallback
    def enable_extension(name)
      super
    rescue ActiveRecord::StatementInvalid => e
      return false unless name.to_s == "pg_cron"
      return false unless e.message.include?("pg_cron")

      Rails.logger.warn("[test] Skipping unavailable PostgreSQL extension pg_cron")
      false
    end
  end

  prepend PgCronTestFallback
end
