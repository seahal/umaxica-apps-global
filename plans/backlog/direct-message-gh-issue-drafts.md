# Direct Message GitHub Issue Drafts

## Japanese Abstract

GitHub issue creation was blocked in the current environment. This file keeps the exact issue drafts
for later submission. Use these drafts when GitHub issue creation is available.

## Draft 1

### Title

`[plan] Assess MIC filing readiness for one-to-one direct messaging in Japan`

### Body

## Japanese Abstract

1 on 1 direct message may require telecom filing review in Japan. We need a clear MIC-facing
readiness track before launch. This issue covers qualification and filing preparation only.

## Summary

The repository already contains a message domain skeleton:

- `config/routes/core.rb` exposes `messages` endpoints on app/com/org
- `app/controllers/core/*/edge/v0/messages_controller.rb` exposes a placeholder JSON contract
- `db/message_schema.rb` contains message-related tables in the `message` database

This means product intent already exists, but the telecom compliance path is not yet documented or
gated.

For Japan-facing one-to-one direct messaging, we should treat legal qualification and filing
readiness as a release blocker.

## Scope

- Confirm the current internal assumption that one-to-one direct messaging requires telecom filing
  review in Japan
- Prepare an internal checklist for MIC consultation or filing preparation
- Define the release gate for any production-ready direct message rollout
- Record the legal assumption in repository planning material

## Out of scope

- Final legal opinion from outside counsel
- Full communication secrecy operating model
- Final persistence or UX implementation of direct messaging

## Inputs

- `plans/backlog/direct-message-telecom-compliance-plan.md`
- `config/routes/core.rb`
- `app/controllers/core/app/edge/v0/messages_controller.rb`
- `app/controllers/core/com/edge/v0/messages_controller.rb`
- `app/controllers/core/org/edge/v0/messages_controller.rb`
- `db/message_schema.rb`

## Deliverables

- Internal filing-readiness checklist
- Explicit launch gate for direct messaging
- Follow-up tasks if regulator consultation is required

## Acceptance criteria

- The repository contains a clear planning note that direct messaging is blocked on telecom
  compliance review
- Filing-readiness work items are listed and actionable
- The team can answer whether the feature is still placeholder-only or allowed to proceed toward
  launch

## Draft 2

### Title

`[docs] Prepare user-facing terms and privacy notices for direct messaging`

### Body

## Japanese Abstract

Users need clear notice before direct message launch. This issue tracks the terms and privacy text
for the feature. The text must exist before production rollout.

## Summary

If this service ships one-to-one direct messaging, users need clear and stable documentation before
launch.

At minimum, the service should not launch without:

- terms coverage for permitted and prohibited message use
- privacy notice coverage for message-related data handling
- a service notice that explains retention, moderation, and legal response at a high level

A draft source now exists in:

- `plans/backlog/direct-message-user-notice-draft.md`

## Scope

- Prepare user-facing terms additions for direct messaging
- Prepare privacy notice additions for message-related data
- Prepare a service notice or equivalent product-facing explanation page
- Align the language across app/com/org where needed

## Out of scope

- Final legal approval of publication text
- Full communication secrecy operations design
- Translation and localization rollout beyond the initial draft set

## Inputs

- `plans/backlog/direct-message-user-notice-draft.md`
- `plans/backlog/direct-message-telecom-compliance-plan.md`

## Deliverables

- Draft terms text
- Draft privacy notice text
- Draft user notice text for the product surface or support page

## Acceptance criteria

- A complete draft exists for the minimum user-facing legal and product notice set
- The drafts clearly describe prohibited use, message-related data handling, and retention / legal
  response at a high level
- The drafts are ready for legal and product review before implementation moves toward launch

## Draft 3

### Title

`[plan] Define message retention, disclosure, deletion, and incident operations`

### Body

## Japanese Abstract

Direct messaging also needs operating procedures. This issue tracks retention, disclosure, deletion,
and incident handling. Communication secrecy design will be handled separately.

## Summary

A direct message feature cannot be treated as a UI-only feature. It also needs explicit operational
handling for message-related records and regulated responses.

This issue tracks the non-UI operational layer for direct messaging:

- retention and deletion flow
- disclosure response flow
- preservation or hold flow where required
- incident and outage handling
- action traceability

## Scope

- Define retention and deletion expectations for message-related records
- Define the internal disclosure response path for valid legal requests
- Define evidence preservation or legal hold touchpoints where direct messaging intersects with
  existing activity retention work
- Define incident and outage handling expectations for the message feature
- Define what action logs or audit traces are required around message operations

## Out of scope

- Detailed communication secrecy policy and operator access design
- Final storage engine implementation
- Full moderation policy design

## Related

- `plans/backlog/direct-message-telecom-compliance-plan.md`
- `plans/backlog/direct-message-user-notice-draft.md`
- #637 legal hold mechanism for activity audit system
- #638 SNS post and comment audit tables
- #639 TTL purge job for expired activity records
- #640 S3 cold archive pipeline for activity records

## Deliverables

- Operations checklist for direct message data lifecycle
- Clear dependency map to existing legal-hold / purge / archive work
- Follow-up implementation tasks for the message domain

## Acceptance criteria

- The team has a written operations view for retention, deletion, disclosure response, and incident
  handling
- Dependencies on existing audit or legal-hold issues are explicit
- The issue produces concrete follow-up work instead of a vague policy note
