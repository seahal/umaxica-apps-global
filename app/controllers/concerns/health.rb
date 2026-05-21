# typed: false
# frozen_string_literal: true

module Health
  extend ActiveSupport::Concern

  DATABASE_RECORD_CLASSES = [
    ChronicleRecord,
    AvatarRecord,
    AppPrincipalRecord,
    AppTicketRecord,
    AppRpRecord,
    AppSignalRecord,
    AppSettingRecord,
    OrgPrincipalRecord,
    OrgTicketRecord,
    OrgRpRecord,
    OrgSignalRecord,
    OrgSettingRecord,
    ComPrincipalRecord,
    ComTicketRecord,
    ComRpRecord,
    ComSignalRecord,
    ComSettingRecord,
    OccurrenceRecord,
  ].freeze

  DB_ROLES = %i(writing reading).freeze

  private

  def get_status
    return [503, "BOOTING"] unless Rails.application.initialized?

    errors = check_dependencies

    if errors.empty?
      [200, "OK", nil, Rails.app.revision.to_s]
    else
      [503, "UNHEALTHY", errors, Rails.app.revision.to_s]
    end
  rescue StandardError => e
    Rails.logger.info(LogEvent.format("health_check.failed", error_class: e.class.name, error_message: e.message))
    [503, "ERROR"]
  end

  def check_dependencies
    errors = []
    check_databases(errors)
    check_redis(errors)
    errors
  end

  def check_databases(errors)
    # Pause Prosopite because we're intentionally querying multiple databases in a loop
    Prosopite.pause if defined?(Prosopite)

    DATABASE_RECORD_CLASSES.each do |klass|
      DB_ROLES.each do |role|
        klass.connected_to(role: role) do
          klass.with_connection { |conn| conn.execute("SELECT 1") }
        rescue StandardError => e
          Rails.logger.info(LogEvent.format(
            "health_check.database_failed", database: klass.name, role: role.to_s,
                                            error_class: e.class.name, error_message: e.message,
          ))
          errors << "Database #{klass.name}(#{role}) unavailable"
        end
      end
    end
    errors
  ensure
    Prosopite.resume if defined?(Prosopite)
  end

  def check_redis(errors)
    if defined?(Redis) && defined?(REDIS_CLIENT)
      begin
        REDIS_CLIENT.ping
      rescue StandardError => e
        Rails.logger.info(LogEvent.format("health_check.redis_failed", error_class: e.class.name, error_message: e.message))
        errors << "Redis unavailable"
      end
    end
    errors
  end

  def show_plain_text
    @status, @body, @errors, @revision = get_status
    timestamp = Time.now.utc.iso8601
    if @errors.present?
      render plain: "#{@body}: #{@errors.join(", ")} (#{timestamp}) #{@revision}", status: @status
    else
      render plain: "#{@body} (#{timestamp})  #{@revision}", status: @status
    end
  end

  def show_json
    @status, @body, @errors = get_status
    response_body = { status: @body, timestamp: Time.now.utc.iso8601, revision: @revision }
    response_body[:errors] = @errors if @errors.present?
    render json: response_body, status: @status
  end
end
