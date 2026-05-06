# Feature Notes

## Customer / Identity

- How much `customer` should be included in the `Identity` contract is still under discussion.
- At present, it can share the same `status_id` and `withdrawable` concepts as `user` and `staff`.
- However, whether `customer` should be treated as a peer auth subject or as a subordinate
  inquiry-only subject is still undecided.
- Until that is settled, keep `customer` auth integration to a minimum.
