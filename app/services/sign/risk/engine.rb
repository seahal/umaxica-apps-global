# typed: false
# frozen_string_literal: true

module Sign
  module Risk
    class Engine
      WINDOW = 5.minutes

      # Returns integer score 0..100
      def self.score(user_id: nil, staff_id: nil, visitor_id: nil)
        return 0 unless user_id || staff_id || visitor_id

        window_start = WINDOW.ago

        if staff_id
          score_for_staff(staff_id, window_start)
        elsif visitor_id
          score_for_visitor(visitor_id, window_start)
        else
          score_for_user(user_id, window_start)
        end
      end

      def self.score_for_user(user_id, window_start)
        scope = ClientOccurrence
          .where("event_type LIKE ?", "risk.%")
          .where("context @> ?", { user_id: user_id }.to_json)
          .where(created_at: window_start..)

        evaluate_rules(scope)
      end

      def self.score_for_staff(staff_id, window_start)
        scope = OperatorOccurrence
          .where("event_type LIKE ?", "risk.%")
          .where("context @> ?", { staff_id: staff_id }.to_json)
          .where(created_at: window_start..)

        evaluate_rules(scope)
      end

      def self.score_for_visitor(visitor_id, window_start)
        scope = VisitorOccurrence
          .where("event_type LIKE ?", "risk.%")
          .where("context @> ?", { visitor_id: visitor_id }.to_json)
          .where(created_at: window_start..)

        evaluate_rules(scope)
      end

      def self.evaluate_rules(scope)
        # Rule 1: Refresh Token Reuse Detected -> 100
        if scope.exists?(event_type: "risk.refresh_reuse_detected")
          return 100
        end

        # Rule 2: Auth Failed 5+ times in window -> 60
        if scope.where(event_type: "risk.auth_failed").count >= 5
          return 60
        end

        # Rule 3: Refresh Failed 5+ times in window -> 40
        if scope.where(event_type: "risk.refresh_failed").count >= 5
          return 40
        end

        0
      end

      private_class_method :score_for_user, :score_for_staff, :score_for_visitor, :evaluate_rules
    end
  end
end
