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
          Rails.logger.info(
            LogEvent.format(
              "health_check.database_failed", database: klass.name, role: role.to_s,
                                              error_class: e.class.name, error_message: e.message,
            ),
          )
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
        Rails.logger.info(
          LogEvent.format(
            "health_check.redis_failed", error_class: e.class.name,
                                         error_message: e.message,
          ),
        )
        errors << "Redis unavailable"
      end
    end
    errors
  end

  def show_plain_text
    return show_json if request.format.json?

    @status, @body, @errors, @revision = get_status
    response_body = health_response_body(@body, @revision)
    if @errors.present?
      render plain: "#{health_plain_text(response_body)} errors=#{@errors.join(", ")}", status: @status
    else
      render plain: health_plain_text(response_body), status: @status
    end
  end

  def show_json
    @status, @body, @errors, @revision = get_status
    response_body = health_response_body(@body, @revision)
    response_body[:errors] = @errors if @errors.present?
    render json: response_body, status: @status
  end

  def health_response_body(status, revision)
    {
      status: status,
      service: health_service_name,
      version: revision,
      time: Time.now.utc.iso8601(3),
    }
  end

  def health_plain_text(response_body)
    response_body.map { |key, value| "#{key}=#{value}" }.join(" ")
  end

  def health_service_name
    self.class.name.deconstantize.split("::").first.underscore
  end
end
