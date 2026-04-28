# Task 4 Secret Rotation Validation Log

Last updated: 2026-03-04


## Target Secret
- Secret path: `kv/dev/jenkins/dockerhub`
- Rotated fields: `username`, `token`
- Rotation date (UTC): `PENDING`

## Rotation Steps
1. Create a new provider token in DockerHub.
2. Write it to Vault:
```bash
vault kv put kv/dev/jenkins/dockerhub username="<dockerhub_user>" token="<new_token>"
```
3. Trigger Jenkins pipeline run.
4. Confirm image push succeeds.
5. Revoke old provider token.

## Verification
- Jenkins build URL: `PENDING`
- Expected: image push stages succeed with Vault runtime credentials.
- Result: `PENDING`

## Rollback (if needed)
1. Restore previous known-good token in Vault.
2. Re-run pipeline to verify recovery.
3. Re-attempt rotation with corrected token scope.

