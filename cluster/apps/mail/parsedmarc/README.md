# parsedmarc

Pulls DMARC aggregate / failure / SMTP-TLS reports out of a Google Workspace
mailbox, parses them, and writes to the `parsedmarc` database on the shared
CNPG cluster. Grafana reads it through the `parsedmarc` datasource; the
dashboard is `cluster/core/monitoring-system/dashboards/parsedmarc.json`.

No OpenSearch. The PostgreSQL backend landed in parsedmarc 10 and creates its
own tables with `CREATE TABLE IF NOT EXISTS`, so there is no schema step.

## Google Workspace setup

Service account + domain-wide delegation, not the OAuth installed-app flow:
the latter needs a browser once and a refresh token that survives forever,
neither of which suits a pod.

1. Google Cloud console, in any project: enable the **Gmail API**.
2. IAM & Admin → Service Accounts → create one → Keys → **Add key → JSON**.
   Download it.
3. Copy that service account's **Client ID** (the numeric OAuth2 one, on its
   Details page -- not the `...iam.gserviceaccount.com` address).
4. Workspace Admin console → Security → Access and data control → **API
   controls → Domain-wide delegation → Add new**:
   - Client ID: the number from step 3
   - OAuth scope: `https://www.googleapis.com/auth/gmail.modify`

   `modify` rather than `readonly` because parsedmarc relabels each message
   once it is saved; that is what stops it reprocessing the backlog forever.
5. Rewrite the secret from the downloaded key:

   ```bash
   cd ~/git/home-network/cluster/apps/mail/parsedmarc
   KEY=~/Downloads/<the-key>.json
   MAILBOX=dmarc@<domain>          # the mailbox the reports land in
   cat > gmail-sa.sops.yaml <<YAML
   ---
   apiVersion: v1
   kind: Secret
   metadata:
     name: parsedmarc-gmail
     namespace: mail
   type: Opaque
   stringData:
     delegated-user: ${MAILBOX}
     service-account.json: |
   $(sed 's/^/    /' "$KEY")
   YAML
   sops -e -i gmail-sa.sops.yaml
   ```

   Then `shred -u "$KEY"`.

## The backlog

`paginate_messages = True` and no `since`, so the first run walks the whole
mailbox rather than the most recent 100 messages. Years of reports is a long
first pass -- hours, not minutes -- and progress is visible as row counts:

```bash
kubectl --context home exec -n database-system postgres-1 -- \
  psql -d parsedmarc -c 'SELECT count(*) FROM dmarc_aggregate_record'
```

If that stays at zero, `reports_folder` is the first thing to check: it
defaults to `INBOX`, and reports filtered into a label years ago are not in
the inbox. The folder name is the Gmail label.

DNS deliberately stays on the parsedmarc default (Cloudflare) rather than
cluster DNS -- a multi-year backfill is tens of thousands of PTR and TXT
lookups, which is not a load to put through pihole.

Logs are errors and warnings only. For a noisy run, add `verbose = True`
under `[general]` in `configmap.yaml`.

## Rotating the database password

Three copies, all the same value:

- `cluster/apps/database-system/postgres-role-parsedmarc.sops.yaml` (CNPG)
- `pgsql-secret.sops.yaml` (this pod)
- `cluster/core/monitoring-system/parsedmarc-pgsql-secret.sops.yaml` (Grafana)
