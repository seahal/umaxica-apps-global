# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      # adr/unified-enforcement.md, Approval / Operator safety. Noun-resource
      # controller per .agents/harnesses/rules/generic/routing.mdc -- no
      # `ban`/`approve`/`release` actions here; those are the nested `approval`
      # and `release` resources (EnforcementCases::ApprovalsController /
      # ::ReleasesController).
      class EnforcementCasesController < Base::Org::ApplicationController
        include EnforcementCaseRealmResolvable

        AUTHENTICATION_MODE = :private

        declare_authentication_mode! :private
        before_action :require_enforcement_step_up!
        before_action :authorize_enforcement_index!, only: :index
        before_action :set_enforcement_case, only: :show

        def index
          cases = enforcement_case_class
            .where(principal_public_id: params[:principal_public_id])
            .order(created_at: :desc)
          render json: { enforcement_cases: cases.map { |c| enforcement_case_json(c) } }
        end

        def show
          authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :show?)
          render json: enforcement_case_json(@enforcement_case)
        end

        def create
          authorize!(enforcement_case_class.new, with: EnforcementCasePolicy, to: :create?)

          enforcement_case = build_enforcement_case
          if enforcement_case.requires_approval?
            enforcement_case.state = "pending_approval"
            enforcement_case.save!
            render json: enforcement_case_json(enforcement_case), status: :accepted
            return
          end

          attach_requested_effects!(enforcement_case)
          EnforcementCaseApplyOperation.call(enforcement_case: enforcement_case)
          render json: enforcement_case_json(enforcement_case), status: :created
        rescue ActiveRecord::RecordInvalid, ArgumentError => e
          render json: { error: e.message }, status: :unprocessable_content
        end

        private

        def require_enforcement_step_up!
          require_step_up!(scope: "enforcement_case_apply")
        end

        def authorize_enforcement_index!
          authorize!(enforcement_case_class.new, with: EnforcementCasePolicy, to: :index?)
        end

        def set_enforcement_case
          @enforcement_case = enforcement_case_class.find_by!(public_id: params.expect(:id))
        end

        def build_enforcement_case
          enforcement_case_class.new(
            enforcement_case_params.merge(applied_by_operator_public_id: current_operator.public_id),
          )
        end

        def enforcement_case_params
          params.expect(
            enforcement_case: %i(kind duration_mode visibility release_mode effective_at expires_at
                                 review_due_at reason_code reason_note ticket_id principal_public_id
                                 break_glass break_glass_approved_by_operator_public_id),
          )
        end

        # Only reached on the no-approval-required path (D12) -- a Case that
        # requires approval carries no effects until EnforcementCases::ApprovalsController
        # attaches and confirms them.
        def attach_requested_effects!(enforcement_case)
          if (attrs = params[:principal_effect]).present?
            enforcement_case.build_principal_effect(principal_effect_params(attrs))
          end
          if (attrs = params[:authentication_method_effect]).present?
            enforcement_case.authentication_method_effects.build(authentication_method_effect_params(attrs))
          end
          if (attrs = params[:identifier_effect]).present?
            enforcement_case.identifier_effects.build(identifier_effect_params(attrs))
          end
        end

        def principal_effect_params(attrs)
          attrs.permit(
            :principal_public_id, :access_blocking, :recovery_blocked, :reactivation_blocked,
            :withdrawal_purge_blocked, :principal_hard_delete_blocked, :profile_effect, :effective_at,
          ).to_h.merge(effective_at: attrs[:effective_at].presence || Time.current)
        end

        def authentication_method_effect_params(attrs)
          attrs.permit(
            :principal_public_id, :authentication_method, :effect, :effective_at,
          ).to_h.merge(effective_at: attrs[:effective_at].presence || Time.current)
        end

        def identifier_effect_params(attrs)
          digest = EnforcementIdentifierDigest.for_email(
            realm: params[:realm],
            value: attrs[:email],
          ) if attrs[:email].present?
          digest ||= EnforcementIdentifierDigest.for_telephone(
            realm: params[:realm],
            value: attrs[:telephone],
          ) if attrs[:telephone].present?
          raise ArgumentError, "identifier_effect requires email or telephone" unless digest

          digest.merge(
            registration_blocked: ActiveModel::Type::Boolean.new.cast(attrs[:registration_blocked]),
            attachment_blocked: ActiveModel::Type::Boolean.new.cast(attrs[:attachment_blocked]),
            recovery_blocked: ActiveModel::Type::Boolean.new.cast(attrs[:recovery_blocked]),
            effective_at: Time.current,
          )
        end

        def enforcement_case_json(enforcement_case)
          {
            public_id: enforcement_case.public_id,
            kind: enforcement_case.kind,
            state: enforcement_case.state,
            duration_mode: enforcement_case.duration_mode,
            visibility: enforcement_case.visibility,
            release_mode: enforcement_case.release_mode,
            effective_at: enforcement_case.effective_at,
            expires_at: enforcement_case.expires_at,
            ended_at: enforcement_case.ended_at,
            end_reason: enforcement_case.end_reason,
            reason_code: enforcement_case.reason_code,
            principal_public_id: enforcement_case.principal_public_id,
            applied_by_operator_public_id: enforcement_case.applied_by_operator_public_id,
            approved_by_operator_public_id: enforcement_case.approved_by_operator_public_id,
            requires_approval: enforcement_case.requires_approval?,
          }
        end
      end
    end
  end
end
