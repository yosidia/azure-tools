# AI Foundry — KQL Monitoring Queries

KQL queries for Azure Monitor (Application Insights and/or the Log Analytics
Workspace behind it) to diagnose issues and alert on Azure AI Foundry agent
behavior.

| File | Purpose |
|---|---|
| [`diagnose-filesearch.kql`](diagnose-filesearch.kql) | Ad-hoc troubleshooting queries for a `file_search` / `msearch` "server_error" from a Foundry agent: finds the actual outbound call to AI Search, surfaces every error/exception tied to file search in the last 30 minutes, and lets you drill into one failing run by trace/operation id. |
| [`agent-monitoring-alerts.md`](agent-monitoring-alerts.md) | A catalog of production alert queries (Token Usage, Quality Absolute Threshold, Quality Regression, Inference Failure Rate) plus 13 additional best-practice metrics (latency, throttling, tool-call errors, cost per session, safety violations, groundedness, and more), each provided in both App Insights and Log Analytics Workspace (LAW) schema variants, with a recommended implementation priority order. |

## How to use these

1. Open **Application Insights** (or the **Log Analytics Workspace** it's
   linked to) for your Foundry account → **Logs**.
2. Paste the relevant query and adjust the time range (`ago(...)`) as needed.
3. For the alert queries in `agent-monitoring-alerts.md`, create an
   **Azure Monitor Alert Rule** (Scheduled query) using the query and the
   suggested aggregation/measure/operator/threshold noted under each one.
4. If you're querying a workspace-based App Insights resource directly via
   the Log Analytics workspace (rather than through the App Insights blade),
   use the `AppXxx` table names called out at the bottom of
   `diagnose-filesearch.kql` (`traces` → `AppTraces`, `exceptions` →
   `AppExceptions`, etc., and `Properties` instead of `customDimensions`) —
   or use the LAW-schema variant already provided for each alert query in
   `agent-monitoring-alerts.md`.

## Requirements

- Azure AI Foundry agents instrumented to emit GenAI semantic-convention
  telemetry (`gen_ai.*` custom dimensions) to Application Insights — this is
  enabled via the Foundry project's App Insights connection (see the
  Terraform `monitoring` module and `foundryProject` module's
  `app_insights_connection_string` wiring in [`../terraform/`](../terraform/)).
- Reader access to the Application Insights resource / Log Analytics
  workspace to run the queries, and Monitoring Contributor (or similar) to
  create alert rules from them.
