# typed: false
# frozen_string_literal: true

module Sign
  module DbscRegistrationEndpoint
    extend ActiveSupport::Concern

    def create
      response.set_header("Cache-Control", "no-store")

      if request.headers[Auth::IoKeys::Headers::DBSC_SESSION_ID].present?
        handle_bound_cookie_refresh
      else
        handle_registration
      end
    end

    private

    def load_current_resource
      return nil if extract_access_token(Authentication::Base::ACCESS_COOKIE_KEY).blank?

      super
    end

    def dbsc_token_record
      token_from_refresh_cookie || current_session
    end

    def token_from_refresh_cookie
      refresh_plain = cookies[Authentication::Base::REFRESH_COOKIE_KEY].to_s
      refresh_public_id, = token_class.parse_refresh_token(refresh_plain)
      find_refresh_token_record(refresh_public_id)
    rescue StandardError
      nil
    end

    def handle_registration
      result = Dbsc::RegistrationService.call(
        record: dbsc_token_record,
        proof: request.headers[Auth::IoKeys::Headers::DBSC_RESPONSE],
        expected_audience: dbsc_url,
      )

      if result[:ok]
        token_record = result[:record]
        set_dbsc_cookie!(result[:session_id], expires_at: dbsc_cookie_expires_at_for(token_record))
        render json: {
          session_identifier: result[:session_id],
          refresh_url: dbsc_url,
          scope: {
            origin: request.base_url,
            include_site: false,
          },
          credentials: [
            {
              type: "cookie",
              name: Authentication::Base::DBSC_COOKIE_KEY,
              attributes: dbsc_cookie_attributes_string,
            },
          ],
        }, status: :created
      else
        render json: { error: "DBSC registration failed", error_code: result[:error_code] },
               status: :unprocessable_content
      end
    end

    def handle_bound_cookie_refresh
      token_record = dbsc_token_record
      return head :unauthorized if token_record.blank?

      session_id = request.headers[Auth::IoKeys::Headers::DBSC_SESSION_ID]
      proof = request.headers[Auth::IoKeys::Headers::DBSC_RESPONSE]
      parsed_session_id = Dbsc::HeaderParser.string_value(session_id)

      if proof.blank?
        challenge = issue_dbsc_challenge_for!(token_record)
        response.set_header(Auth::IoKeys::Headers::DBSC_CHALLENGE, %("#{challenge}";id="#{parsed_session_id}"))
        return head :forbidden
      end

      result = Dbsc::VerificationService.call(
        record: token_record, session_id: session_id, proof: proof,
        expected_audience: dbsc_url,
      )
      return render json: { error: "DBSC verification failed", error_code: result[:error_code] },
                    status: :unprocessable_content unless result[:ok]

      token_record.update!(dbsc_challenge: nil, dbsc_challenge_issued_at: nil)
      set_dbsc_cookie!(token_record.dbsc_session_id, expires_at: dbsc_cookie_expires_at_for(token_record))
      head :no_content
    end

    def dbsc_cookie_attributes_string
      [
        "Path=/",
        ("Secure" if Rails.env.production?),
        "HttpOnly",
        "SameSite=Lax",
      ].compact.join("; ")
    end

    # Subclasses must implement:
    #   def dbsc_url = <route helper returning full URL>
  end
end
