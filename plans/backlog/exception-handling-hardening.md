# Exception Handling Hardening Plan

## Problem

In this repository, you can catch a wide range of unexpected exceptions.`rescue StandardError` There
are many similar catches. As a result, bugs that should have surfaced in 5xx are being ignored,
slowing down root cause tracking and correction.

## Goal

- As a general rule, unexpected exceptions are not suppressed and exposed as 5xx.
- Handle only expected branches with individual exceptions.
- Reduce "rescue to hide failures" and make it easier to detect failures.

## Proposed Steps

1. Inventory `rescue StandardError` and `rescue nil`.
2. For each exception, leave only expected branches and resubmit the rest.
3. The controller is limited to the responsibility of the HTTP layer, and service layer failures are
   returned with an explicit exception or result object.
4. Check the cases that should be 5xx through integration testing.

## Scope Notes

- Review across areas such as DBSC / preference / auth / token / social login.
- However, individual rescue is allowed for "business failures" such as external API malfunctions
  and incorrect input.
- The goal is not to have zero exceptions, but to stop unnecessary concealment.

## Verification

- Check whether the HTTP status at the time of failure does not change before and after reducing
  `rescue StandardError`.
- Add tests that return unexpected exceptions in the 500 series to important public / sign routes.
- If you have existing logging or monitoring alerts, also make sure that the exception is no longer
  caught.
