# azure-tools

Azure infrastructure solutions, scripts, and best practices — reusable Terraform
modules, operational PowerShell scripts, and KQL monitoring queries collected
from real-world Azure deployments and sanitized for public sharing.

Everything here is generic and parameterized: no subscription IDs, tenant
names, internal IP ranges, or customer-specific values. Copy what you need,
plug in your own environment values, and adapt to your landing zone.

## Contents

| Area | Description |
|---|---|
| [`ai-foundry/`](ai-foundry/) | Azure AI Foundry (Azure AI Studio) private/secure landing zone: Terraform modules, operational PowerShell scripts, and KQL monitoring queries. |

More solution areas will be added over time — see each directory's own
README for details on what's inside and how to use it.

## Usage

Each subdirectory is self-contained with its own README explaining
prerequisites, parameters, and usage examples. Nothing here should be
`terraform apply`'d or run blindly against production — review the code,
adapt variable values to your environment, and test in a non-production
subscription first.

## Contributing / feedback

This repo is a personal collection of field-tested patterns. Issues and pull
requests with improvements, fixes, or additional best practices are welcome.

## License

[MIT](LICENSE) — use freely, no warranty implied.
