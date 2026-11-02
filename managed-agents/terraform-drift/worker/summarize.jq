# Input: terraform show -json tfplan. Output: only addresses, actions and attribute NAMES.
def changed_keys:
  (.before // {}) as $b | (.after // {}) as $a
  | (($b | keys) + ($a | keys)) | unique | map(select($b[.] != $a[.]));

{
  workspace: $ws,
  status: "changes",
  drift: [
    .resource_drift[]?
    | { fingerprint: "\($ws)|\(.address)|\(.change | changed_keys | join(","))",
        address, type, actions: .change.actions, keys: (.change | changed_keys) }
  ],
  pending: [
    .resource_changes[]?
    | select(.change.actions != ["no-op"])
    | { address, actions: .change.actions }
  ]
}
