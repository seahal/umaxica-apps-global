# Direct Message Telecom Compliance Plan

## Japanese Abstract

1 on 1 direct message is likely a telecommunications business feature in Japan. This plan tracks the
compliance work before the feature becomes real. The main regulator is the Ministry of Internal
Affairs and Communications.

## Summary

This repository already contains a message domain skeleton:

- message routes on app/com/org surfaces
- edge API placeholder controllers
- a dedicated `message` database with message-related tables

However, the current implementation does not yet show the legal and operational controls that are
normally required when a service mediates user-to-user communication in Japan.

For this project, we should treat one-to-one direct messaging as a feature that requires explicit
telecom compliance review before production release.

## Why This Needs a Separate Track

Direct messaging is not only a product feature. It changes the regulatory posture of the service.

The implementation must not proceed as a normal CRUD feature only. It needs:

- a legal qualification check under the Telecommunications Business Act
- regulator-facing filing and consultation work
- user-facing notice and contract updates
- operational controls for retention, disclosure response, deletion, and incident handling

## Confirmed Repository State

The following primary sources exist in the repository today:

- `config/routes/core.rb` exposes `messages` endpoints on app/com/org
- `app/controllers/core/*/edge/v0/messages_controller.rb` returns a placeholder JSON contract
- `app/controllers/concerns/core/edge/v0/messages_endpoint.rb` contains shared placeholder logic
- `db/message_schema.rb` contains `user_messages`, `member_messages`, `staff_messages`,
  `operator_messages`, and `client_messages`
- `test/integration/core_message_edge_v0_test.rb` verifies the placeholder API contract

This means the codebase already signals product intent for a message feature, even though the
behavior is not complete.

## Scope

This plan covers:

- legal qualification review for one-to-one direct message
- implementation gating before production rollout
- user-facing documentation that must exist before launch
- issue decomposition for tracking

This plan does not yet cover:

- communication secrecy operational design in detail
- final data retention duration decisions
- a final legal opinion for any non-Japan jurisdiction

## Working Assumption

Until specialist counsel or MIC consultation says otherwise, assume:

- one-to-one direct message is in scope for telecom filing review in Japan
- launch must be blocked until the filing path is clear
- the product must ship with clear user-facing notice and internal operating procedures

## Delivery Tracks

### Track A: Legal Qualification And Filing Readiness

Goal: Confirm whether the planned direct message feature requires filing, what type of filing is
needed, and what conditions must be met before launch.

Minimum outputs:

- a repository note that states the current legal assumption
- an internal checklist for MIC consultation or filing preparation
- a release gate that prevents silent rollout before legal review completion

### Track B: User-Facing Documentation

Goal: Prepare the minimum user-visible documents required to explain the messaging feature and its
data handling.

Minimum outputs:

- terms update for direct message usage rules
- privacy notice update for message-related personal data
- service notice that explains moderation, disclosure response, and retention at a high level

### Track C: Operational Readiness

Goal: Define the operational controls for evidence preservation and regulated response handling.

Minimum outputs:

- disclosure request handling flow
- deletion and retention flow
- incident and outage communication flow
- traceability for message-related actions

## Proposed Sequence

1. Freeze the current legal assumption in a plan document.
2. Open GitHub issues for the legal, document, and operations tracks.
3. Keep the message endpoints as placeholders until the legal gate is satisfied.
4. Implement the user-facing documents before any production-ready messaging workflow.
5. Design the operations flow for retention, disclosure response, and incidents.
6. Only then move to full message persistence and product rollout.

## Release Gate

Do not consider direct messaging launch-ready until all of the following are true:

- the legal qualification work is complete
- the filing path has been confirmed
- user-facing documents are drafted and approved
- operations for retention and disclosure are defined

## Issue Mapping

Recommended issue split:

1. Legal qualification and MIC filing readiness for one-to-one direct messaging
2. User-facing terms and privacy notice for direct messaging
3. Message retention, disclosure response, deletion, and incident operations
