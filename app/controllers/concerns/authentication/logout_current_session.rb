# typed: false
# frozen_string_literal: true

module Authentication
  class LogoutCurrentSession
    def self.call(...)
      new(...).call
    end

    def initialize(current: nil, resource: nil, token: nil, token_class: nil, session_public_id: nil,
                   reason: "user_logout", cascade_device_session_tokens: true)
      @current = current
      @resource = resource
      @token = token
      @token_class = token_class
      @session_public_id = session_public_id.presence || current_session_from_current
      @reason = reason
      @cascade_device_session_tokens = cascade_device_session_tokens
    end

    def call
      token_record = resolved_token
      revoke_device_session!(token_record)
      revoke_token!(token_record) unless device_session_cascade_handles_token?(token_record)
      true
    end

    private

    attr_reader :current, :resource, :token, :token_class, :session_public_id, :reason,
                :cascade_device_session_tokens

    def current_session_from_current
      return unless current.respond_to?(:session)

      current.session
    end

    def resolved_token
      return token if token.present?
      return if token_class.blank? || session_public_id.blank?

      device_session = token_column?(:device_session_id) ? find_device_session : nil
      if device_session
        return token_class.currently_usable_at
            .where(device_session_id: device_session.id)
            .order(created_at: :desc)
            .first
      end

      find_token_by(:public_id) || find_token_by(:oidc_sid)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotDefined
      nil
    end

    def find_token_by(column)
      return unless token_column?(column)
      return if column == :oidc_sid && !uuid_identifier?(session_public_id)

      token_class.find_by(column => session_public_id)
    end

    def token_column?(column)
      return false unless token_class.respond_to?(:column_names)

      token_class.column_names.include?(column.to_s)
    end

    def uuid_identifier?(value)
      /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(
        value.to_s,
      )
    end

    def find_device_session
      klass = device_session_class
      return unless klass

      klass.active.find_by(public_id: session_public_id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotDefined
      nil
    end

    def device_session_class
      return token.device_session.class if token&.respond_to?(:device_session) && token.device_session.present?

      case token_class&.name
      when "ClientToken" then ClientDeviceSession
      when "OperatorToken" then OperatorDeviceSession
      when "VisitorToken" then VisitorDeviceSession
      end
    end

    def revoke_device_session!(token_record)
      device_session = token_record&.respond_to?(:device_session) ? token_record.device_session : find_device_session
      return if device_session.blank?

      device_session.revoke!(reason: reason)
      return unless cascade_device_session_tokens

      if token_record&.class&.respond_to?(:where)
        token_record.class.where(device_session_id: device_session.id).find_each { |session_token|
          revoke_token!(session_token)
        }
      end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotDefined
      true
    end

    def revoke_token!(token_record)
      return true if token_record.blank?
      return true if token_record.respond_to?(:revoked?) && token_record.revoked?

      if token_record.respond_to?(:revoke!)
        token_record.revoke!
      elsif token_record.respond_to?(:destroy)
        token_record.destroy
      end
      true
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordInvalid => e
      Rails.logger.info(
        LogEvent.format(
          "auth.logout_current_session.failed",
          reason: reason,
          resource_class: resource&.class&.name,
          resource_id: resource&.id,
          token_class: token_record&.class&.name,
          token_id: token_record&.try(:public_id),
          error_class: e.class.name,
          error_message: e.message,
        ),
      )
      true
    end

    def device_session_cascade_handles_token?(token_record)
      cascade_device_session_tokens &&
        token_record&.respond_to?(:device_session) &&
        token_record.device_session.present?
    end
  end
end
