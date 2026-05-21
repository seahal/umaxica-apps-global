# typed: false
# frozen_string_literal: true

module Authentication
  module BulletinGate
    extend ActiveSupport::Concern

    def issue_bulletin!(kind: "checkpoint", state: "new", payload: {})
      bulletin = find_unread_bulletin
      return false unless bulletin

      session[Authentication::Base::BULLETIN_SESSION_KEY] = {
        "issued_at" => Time.current.to_i,
        "kind" => kind.to_s,
        "state" => state.to_s,
        "bulletin_id" => bulletin.id,
      }.merge(payload.stringify_keys)
      true
    end

    def issue_checkpoint!(kind: "checkpoint", state: "new", payload: {})
      return issue_bulletin! if kind.to_s == "checkpoint" && state.to_s == "new" && payload.blank?

      issue_bulletin!(kind: kind, state: state, payload: payload)
    end

    def bulletin_state
      raw = session[Authentication::Base::BULLETIN_SESSION_KEY]
      return nil unless raw.is_a?(Hash)

      raw.with_indifferent_access
    end

    def bulletin_active?
      bulletin_state.present? && !bulletin_expired?
    end

    def bulletin_expired?
      data = bulletin_state
      return true if data.blank?

      issued_at = epoch_seconds(data[:issued_at])
      return true if issued_at <= 0

      Time.current.to_i >= issued_at + Authentication::Base::BULLETIN_TIMEOUT.to_i
    end

    def refresh_bulletin_dimension!(state: "updated")
      data = bulletin_state
      return unless data

      session[Authentication::Base::BULLETIN_SESSION_KEY] = data.merge(
        "issued_at" => Time.current.to_i,
        "state" => state.to_s,
      )
    end

    def consume_bulletin!
      mark_current_bulletin_as_read!
      session.delete(Authentication::Base::BULLETIN_SESSION_KEY)
    end

    def current_bulletin
      data = bulletin_state
      return nil unless data
      return nil unless data[:bulletin_id]

      bulletin_association_for_resource&.find_by(id: data[:bulletin_id])
    end

    private

    def find_unread_bulletin
      bulletin_association_for_resource&.unread&.oldest_first&.first
    end

    def mark_current_bulletin_as_read!
      current_bulletin&.mark_as_read!
    end

    def bulletin_association_for_resource
      resource = current_resource
      return nil unless resource

      case resource
      when Client then resource.client_bulletins
      when Operator then resource.staff_bulletins
      else
        return resource.client_bulletins if resource.respond_to?(:client_bulletins)
        return resource.staff_bulletins if resource.respond_to?(:staff_bulletins)
      end
    end
  end
end
