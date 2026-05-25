# typed: false
# frozen_string_literal: true

module Authentication
  class CurrentResourceResolver
    Result =
      Struct.new(
        :resource,
        :session_public_id,
        :payload,
        :failure_reason,
        keyword_init: true,
      ) do
        def success?
          resource.present?
        end
      end

    def initialize(access_token:, request_host:, resource_type:, resource_class:, token_class:,
                   authorization_scheme: nil, dpop_proof: nil, request_method: nil, request_uri: nil)
      @access_token = access_token
      @request_host = request_host
      @resource_type = resource_type
      @resource_class = resource_class
      @token_class = token_class
      @authorization_scheme = authorization_scheme
      @dpop_proof = dpop_proof
      @request_method = request_method
      @request_uri = request_uri
    end

    def call
      return failure(:blank_access_token) if @access_token.blank?

      payload = Authentication::Base::Token.decode(@access_token, host: @request_host, resource_type: @resource_type)
      if payload.blank?
        sid = Authentication::Base::Token.extract_session_id_allow_expired(
          @access_token,
          host: @request_host,
          resource_type: @resource_type,
        )
        return failure(:token_decode_failed, session_public_id: sid) if sid.present?

        return failure(:token_decode_failed)
      end
      return failure(:dpop_verification_failed, payload: payload) unless dpop_valid?(payload)

      unless Authentication::Base::Token.validate_actor_claim!(payload, @resource_type)
        return failure(:actor_mismatch, payload: payload)
      end

      sid = Authentication::Base::Token.extract_session_id(payload)
      return failure(:missing_session_id, payload: payload) if sid.blank?

      token_record = token_record_for_session_identifier(sid)
      return failure(:token_session_not_found, payload: payload) unless token_record
      return failure(:dpop_binding_mismatch, payload: payload) unless token_dpop_binding_current?(token_record, payload)
      return failure(:token_jti_mismatch, payload: payload) unless token_jti_current?(token_record, payload)

      resource = @resource_class.find_by(id: Authentication::Base::Token.extract_subject(payload))
      return failure(
        :resource_not_found, payload: payload,
                             session_public_id: current_session_public_id(token_record, sid),
      ) if resource.blank?

      Result.new(
        resource: resource,
        session_public_id: current_session_public_id(token_record, sid),
        payload: payload,
        failure_reason: nil,
      )
    end

    private

    def dpop_valid?(payload)
      token_jkt = payload.dig("cnf", "jkt")
      scheme = @authorization_scheme.to_s
      scheme_dpop = scheme.casecmp?("DPoP")

      return true if token_jkt.blank? && !scheme_dpop && @dpop_proof.blank?
      return false unless scheme_dpop
      return false if token_jkt.blank?

      result = Dpop::RequestVerifier.new(
        access_token_payload: payload,
        proof_jwt: @dpop_proof,
        request_method: @request_method,
        request_uri: @request_uri,
        access_token: @access_token,
      ).call

      result.valid?
    end

    def token_record_for_session_identifier(session_identifier)
      check_logic =
        lambda do
          base_scope =
            if @token_class.respond_to?(:currently_usable_at)
              @token_class.currently_usable_at
            else
              @token_class.where(nil)
            end
          usable_tokens = base_scope.includes(:device_session)
          device_session = token_column?("device_session_id") ? device_session_for(session_identifier) : nil
          if device_session
            token = usable_tokens.where(device_session_id: device_session.id).order(created_at: :desc).first
            return token if token
          end
          scope = usable_tokens.where(public_id: session_identifier)
          if token_column?("oidc_sid") && uuid_identifier?(session_identifier)
            scope = scope.or(usable_tokens.where(oidc_sid: session_identifier))
          end
          scope.first
        end

      # Use the primary database for revocation-sensitive checks so a recently
      # revoked session cannot slip through replica lag.
      operation = lambda { token_connection_owner.connected_to(role: :writing, &check_logic) }
      defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    end

    def current_session_public_id(token_record, session_identifier)
      token_record&.try(:device_session)&.public_id.presence || token_record&.public_id.presence || session_identifier
    end

    def token_jti_current?(token_record, payload)
      oidc_jti = token_record_attribute(token_record, :oidc_jti)
      return true if oidc_jti.blank?

      payload_jti = Authentication::Base::Token.extract_jti(payload)
      ActiveSupport::SecurityUtils.secure_compare(oidc_jti.to_s, payload_jti.to_s)
    end

    def token_dpop_binding_current?(token_record, payload)
      record_jkt = (token_record_attribute(token_record, :dpop_jkt).presence ||
        token_record&.try(:device_session)&.dpop_jkt).to_s
      payload_jkt = payload.dig("cnf", "jkt").to_s
      return true if record_jkt.blank? && payload_jkt.blank?
      return false if record_jkt.blank? || payload_jkt.blank?

      ActiveSupport::SecurityUtils.secure_compare(record_jkt, payload_jkt)
    end

    def token_record_attribute(token_record, attribute)
      return unless token_record&.respond_to?(:has_attribute?) && token_record.has_attribute?(attribute)

      token_record.public_send(attribute)
    end

    def token_column?(column_name)
      return false unless @token_class.respond_to?(:column_names)

      @token_class.column_names.include?(column_name)
    end

    def device_session_for(public_id)
      klass = device_session_class
      return unless klass && public_id.present?

      klass.active.find_by(public_id: public_id)
    end

    def device_session_class
      case @resource_type.to_s
      when "client" then ::ClientDeviceSession
      when "operator" then ::OperatorDeviceSession
      when "visitor" then ::VisitorDeviceSession
      end
    end

    def uuid_identifier?(value)
      /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(
        value.to_s,
      )
    end

    def token_connection_owner
      klass = @token_class
      return OrgTicketRecord unless klass.respond_to?(:connection_class?)

      klass = klass.superclass until klass.connection_class?
      klass
    end

    def failure(reason, payload: nil, session_public_id: nil)
      Result.new(
        resource: nil,
        session_public_id: session_public_id,
        payload: payload,
        failure_reason: reason,
      )
    end
  end
end
