# AI Foundry Agent Monitoring — KQL Alert Queries

## 1. Token Usage

```kql
let application = dynamic(['*']);
let model = dynamic(['*']);
let get_model = (customDimensions: dynamic) { iff(customDimensions["gen_ai.request.model"] == "", customDimensions["gen_ai.response.model"], customDimensions["gen_ai.request.model"]) };
let is_inference_call = (customDimensions: dynamic) {
    customDimensions["gen_ai.system"] != "" and customDimensions["gen_ai.operation.name"] in ("chat", "process_thread_run", "text_completion", "get_thread_run")
};
let filter_inference_model_and_app = (customDimensions: dynamic, app_name: string) {
    is_inference_call(customDimensions) == true and
    ("*" in (model) or array_length(model) == 0 or get_model(customDimensions) in (model)) and
    ('*' in (application) or array_length(application) == 0 or app_name in (application))
};
let base_data = dependencies
    | where filter_inference_model_and_app(customDimensions, cloud_RoleName) == true;
let deduped_data =
    union
        (base_data | where customDimensions["gen_ai.operation.name"] != "get_thread_run"),
        (base_data | where customDimensions["gen_ai.operation.name"] == "get_thread_run"
         | summarize arg_max(timestamp, *) by tostring(customDimensions["gen_ai.thread.run.id"]));
deduped_data
| where filter_inference_model_and_app(customDimensions, cloud_RoleName) == true
| extend Total_Tokens = toint(customDimensions["gen_ai.usage.input_tokens"]) + toint(customDimensions["gen_ai.usage.output_tokens"])
```

**Alert config:** Aggregation = Total, Measure = `Total_Tokens`, Operator = GreaterThan, Threshold = 100,000

---

## 2. Agent Quality — Absolute Threshold

```kql
let application = dynamic(['*']);
let model = dynamic(['*']);
let get_model = (customDimensions: dynamic) { iff(customDimensions["gen_ai.request.model"] == "", customDimensions["gen_ai.response.model"], customDimensions["gen_ai.request.model"]) };
let is_inference_call = (customDimensions: dynamic) {
    customDimensions["gen_ai.system"] != "" and customDimensions["gen_ai.operation.name"] in ("chat", "process_thread_run", "text_completion", "get_thread_run")
};
let filter_model_and_app = (customDimensions: dynamic, app_name: string) {
    ("*" in (model) or array_length(model) == 0 or get_model(customDimensions) in (model)) and
    ('*' in (application) or array_length(application) == 0 or app_name in (application))
};
let filter_inference_model_and_app = (customDimensions: dynamic, app_name: string) {
    is_inference_call(customDimensions) == true and filter_model_and_app(customDimensions, app_name) == true
};
let get_event_name = (customDimensions: dynamic, message: string) {
    iff(customDimensions["event.name"] == "", message, customDimensions["event.name"])
};
let get_evaluator_name = (customDimensions: dynamic, event_name: string) {
    iff(customDimensions["gen_ai.evaluator.name"] == "", split(event_name, ".")[2], tostring(customDimensions["gen_ai.evaluator.name"]))
};
let get_response_id = (customDimensions: dynamic) {
    iff(
        customDimensions["gen_ai.response.id"] == "",
        iff(customDimensions["gen_ai.thread.run.id"] == "", "", strcat(tostring(customDimensions["gen_ai.thread.id"]), "/", tostring(customDimensions["gen_ai.thread.run.id"]))),
        tostring(customDimensions["gen_ai.response.id"])
    )
};
let inference_calls = dependencies
    | where filter_inference_model_and_app(customDimensions, cloud_RoleName) == true
    | project
        customDimensions,
        cloud_RoleName,
        timestamp,
        response_id=get_response_id(customDimensions),
        model=tostring(get_model(customDimensions));
let deduped_inference_calls =
    union
        (inference_calls | where customDimensions["gen_ai.operation.name"] != "get_thread_run"),
        (inference_calls | where customDimensions["gen_ai.operation.name"] == "get_thread_run"
         | summarize arg_max(timestamp, *) by tostring(customDimensions["gen_ai.thread.run.id"]))
    | project response_id, model;
let evals = traces
    | where filter_model_and_app(customDimensions, cloud_RoleName)
    | extend event_name = get_event_name(customDimensions, message)
    | where event_name startswith "gen_ai.evaluation"
    | extend
        evaluator_name = get_evaluator_name(customDimensions, event_name),
        score = todouble(customDimensions["gen_ai.evaluation.score"]),
        response_id=get_response_id(customDimensions),
        evaluator_id=tostring(customDimensions["gen_ai.evaluator.id"]);
evals
| join kind=leftouter deduped_inference_calls on response_id
| where evaluator_id !in~ ("azureai://built-in/evaluators/code_vulnerability", "azureai://built-in/evaluators/hate_unfairness", "azureai://built-in/evaluators/indirect_attack", "azureai://built-in/evaluators/self_harm", "azureai://built-in/evaluators/sexual", "azureai://built-in/evaluators/violence")
| project score
```

**Alert config:** Aggregation = Average, Measure = `score`, Operator = LessThan, Threshold = 3.0

---

## 3. Agent Quality — Regression Detection

```kql
let period = 30m;
let application = dynamic(['*']);
let model = dynamic(['*']);
let get_model = (customDimensions: dynamic) { iff(customDimensions["gen_ai.request.model"] == "", customDimensions["gen_ai.response.model"], customDimensions["gen_ai.request.model"]) };
let is_inference_call = (customDimensions: dynamic) {
    customDimensions["gen_ai.system"] != "" and customDimensions["gen_ai.operation.name"] in ("chat", "process_thread_run", "text_completion", "get_thread_run")
};
let filter_model_and_app = (customDimensions: dynamic, app_name: string) {
    ("*" in (model) or array_length(model) == 0 or get_model(customDimensions) in (model)) and
    ('*' in (application) or array_length(application) == 0 or app_name in (application))
};
let filter_inference_model_and_app = (customDimensions: dynamic, app_name: string) {
    is_inference_call(customDimensions) == true and filter_model_and_app(customDimensions, app_name) == true
};
let change_percent = (final: double, initial: double) {
    iff(initial == 0, iff(final == 0, real(0), real(+inf)), (final - initial) / initial * 100)
};
let get_event_name = (customDimensions: dynamic, message: string) {
    iff(customDimensions["event.name"] == "", message, customDimensions["event.name"])
};
let get_evaluator_name = (customDimensions: dynamic, event_name: string) {
    iff(customDimensions["gen_ai.evaluator.name"] == "", split(event_name, ".")[2], tostring(customDimensions["gen_ai.evaluator.name"]))
};
let get_response_id = (customDimensions: dynamic) {
    iff(
        customDimensions["gen_ai.response.id"] == "",
        iff(customDimensions["gen_ai.thread.run.id"] == "", "", strcat(tostring(customDimensions["gen_ai.thread.id"]), "/", tostring(customDimensions["gen_ai.thread.run.id"]))),
        tostring(customDimensions["gen_ai.response.id"])
    )
};
let inference_calls =
    union
        (dependencies
         | where filter_inference_model_and_app(customDimensions, cloud_RoleName) == true
         | where customDimensions["gen_ai.operation.name"] != "get_thread_run"
         | project response_id=get_response_id(customDimensions), model=tostring(get_model(customDimensions))),
        (dependencies
         | where filter_inference_model_and_app(customDimensions, cloud_RoleName) == true
         | where customDimensions["gen_ai.operation.name"] == "get_thread_run"
         | summarize arg_max(timestamp, *) by tostring(customDimensions["gen_ai.thread.run.id"])
         | project response_id=get_response_id(customDimensions), model=tostring(get_model(customDimensions)));
let evals = traces
    | where filter_model_and_app(customDimensions, cloud_RoleName)
    | extend event_name = get_event_name(customDimensions, message)
    | where event_name startswith "gen_ai.evaluation"
    | extend
        evaluator_name = get_evaluator_name(customDimensions, event_name),
        score = todouble(customDimensions["gen_ai.evaluation.score"]),
        response_id=get_response_id(customDimensions);
let current_scores = evals
    | where timestamp > ago(period)
    | join kind=leftouter inference_calls on response_id
    | summarize current_score=avg(score) by evaluator_name;
let previous_scores = evals
    | where timestamp between(ago(2 * period) .. ago(period))
    | join kind=leftouter inference_calls on response_id
    | summarize previous_score=avg(score) by evaluator_name;
current_scores
| join kind=inner previous_scores on evaluator_name
| extend pct_change = change_percent(current_score, previous_score)
| project evaluator_name, pct_change
```

**Alert config:** Aggregation = Minimum, Measure = `pct_change`, Operator = LessThan, Threshold = -20%, Dimension = `evaluator_name`

---

## 4. Inference Request Failure Rate

```kql
let application = dynamic(['*']);
let model = dynamic(['*']);
let get_model = (customDimensions: dynamic) { iff(customDimensions["gen_ai.request.model"] == "", customDimensions["gen_ai.response.model"], customDimensions["gen_ai.request.model"]) };
let is_inference_call = (customDimensions: dynamic) {
    customDimensions["gen_ai.system"] != "" and customDimensions["gen_ai.operation.name"] in ("chat", "process_thread_run", "text_completion", "get_thread_run")
};
let filter_inference_model_and_app = (customDimensions: dynamic, app_name: string) {
    is_inference_call(customDimensions) == true and
    ("*" in (model) or array_length(model) == 0 or get_model(customDimensions) in (model)) and
    ('*' in (application) or array_length(application) == 0 or app_name in (application))
};
let base_data = dependencies
    | where filter_inference_model_and_app(customDimensions, cloud_RoleName) == true;
let deduped_data =
    union
        (base_data | where customDimensions["gen_ai.operation.name"] != "get_thread_run"),
        (base_data | where customDimensions["gen_ai.operation.name"] == "get_thread_run"
         | summarize arg_max(timestamp, *) by tostring(customDimensions["gen_ai.thread.run.id"]));
deduped_data
| where filter_inference_model_and_app(customDimensions, cloud_RoleName) == true
| summarize total = count(), failures = countif(success == false)
| extend failure_rate = iff(total == 0, 0.0, todouble(failures) / todouble(total) * 100)
| project failure_rate
```

**Alert config:** Aggregation = Maximum, Measure = `failure_rate`, Operator = GreaterThan, Threshold = 10%

---

# Log Analytics Workspace Versions

The queries below are equivalent to the four above but use the **Log Analytics Workspace (LAW)** schema, suitable for running directly against a workspace-based App Insights' linked LAW.

**Schema mapping reference:**

| App Insights | Log Analytics |
|---|---|
| `dependencies` | `AppDependencies` |
| `traces` | `AppTraces` |
| `customDimensions` | `Properties` |
| `cloud_RoleName` | `AppRoleName` |
| `timestamp` | `TimeGenerated` |
| `success` | `Success` |
| `message` | `Message` |

---

## 1. Token Usage (LAW)

```kql
let application = dynamic(['*']);
let model = dynamic(['*']);
let get_model = (Properties: dynamic) { iff(Properties["gen_ai.request.model"] == "", Properties["gen_ai.response.model"], Properties["gen_ai.request.model"]) };
let is_inference_call = (Properties: dynamic) {
    Properties["gen_ai.system"] != "" and Properties["gen_ai.operation.name"] in ("chat", "process_thread_run", "text_completion", "get_thread_run")
};
let filter_inference_model_and_app = (Properties: dynamic, app_name: string) {
    is_inference_call(Properties) == true and
    ("*" in (model) or array_length(model) == 0 or get_model(Properties) in (model)) and
    ('*' in (application) or array_length(application) == 0 or app_name in (application))
};
let base_data = AppDependencies
    | where filter_inference_model_and_app(Properties, AppRoleName) == true;
let deduped_data =
    union
        (base_data | where Properties["gen_ai.operation.name"] != "get_thread_run"),
        (base_data | where Properties["gen_ai.operation.name"] == "get_thread_run"
         | summarize arg_max(TimeGenerated, *) by tostring(Properties["gen_ai.thread.run.id"]));
deduped_data
| where filter_inference_model_and_app(Properties, AppRoleName) == true
| extend Total_Tokens = toint(Properties["gen_ai.usage.input_tokens"]) + toint(Properties["gen_ai.usage.output_tokens"])
```

**Alert config:** Aggregation = Total, Measure = `Total_Tokens`, Operator = GreaterThan, Threshold = 100,000

---

## 2. Agent Quality — Absolute Threshold (LAW)

```kql
let application = dynamic(['*']);
let model = dynamic(['*']);
let get_model = (Properties: dynamic) { iff(Properties["gen_ai.request.model"] == "", Properties["gen_ai.response.model"], Properties["gen_ai.request.model"]) };
let is_inference_call = (Properties: dynamic) {
    Properties["gen_ai.system"] != "" and Properties["gen_ai.operation.name"] in ("chat", "process_thread_run", "text_completion", "get_thread_run")
};
let filter_model_and_app = (Properties: dynamic, app_name: string) {
    ("*" in (model) or array_length(model) == 0 or get_model(Properties) in (model)) and
    ('*' in (application) or array_length(application) == 0 or app_name in (application))
};
let filter_inference_model_and_app = (Properties: dynamic, app_name: string) {
    is_inference_call(Properties) == true and filter_model_and_app(Properties, app_name) == true
};
let get_event_name = (Properties: dynamic, message: string) {
    iff(Properties["event.name"] == "", message, Properties["event.name"])
};
let get_evaluator_name = (Properties: dynamic, event_name: string) {
    iff(Properties["gen_ai.evaluator.name"] == "", split(event_name, ".")[2], tostring(Properties["gen_ai.evaluator.name"]))
};
let get_response_id = (Properties: dynamic) {
    iff(
        Properties["gen_ai.response.id"] == "",
        iff(Properties["gen_ai.thread.run.id"] == "", "", strcat(tostring(Properties["gen_ai.thread.id"]), "/", tostring(Properties["gen_ai.thread.run.id"]))),
        tostring(Properties["gen_ai.response.id"])
    )
};
let inference_calls = AppDependencies
    | where filter_inference_model_and_app(Properties, AppRoleName) == true
    | project
        Properties,
        AppRoleName,
        TimeGenerated,
        response_id=get_response_id(Properties),
        model=tostring(get_model(Properties));
let deduped_inference_calls =
    union
        (inference_calls | where Properties["gen_ai.operation.name"] != "get_thread_run"),
        (inference_calls | where Properties["gen_ai.operation.name"] == "get_thread_run"
         | summarize arg_max(TimeGenerated, *) by tostring(Properties["gen_ai.thread.run.id"]))
    | project response_id, model;
let evals = AppTraces
    | where filter_model_and_app(Properties, AppRoleName)
    | extend event_name = get_event_name(Properties, Message)
    | where event_name startswith "gen_ai.evaluation"
    | extend
        evaluator_name = get_evaluator_name(Properties, event_name),
        score = todouble(Properties["gen_ai.evaluation.score"]),
        response_id=get_response_id(Properties),
        evaluator_id=tostring(Properties["gen_ai.evaluator.id"]);
evals
| join kind=leftouter deduped_inference_calls on response_id
| where evaluator_id !in~ ("azureai://built-in/evaluators/code_vulnerability", "azureai://built-in/evaluators/hate_unfairness", "azureai://built-in/evaluators/indirect_attack", "azureai://built-in/evaluators/self_harm", "azureai://built-in/evaluators/sexual", "azureai://built-in/evaluators/violence")
| project score
```

**Alert config:** Aggregation = Average, Measure = `score`, Operator = LessThan, Threshold = 3.0

---

## 3. Agent Quality — Regression Detection (LAW)

```kql
let period = 30m;
let application = dynamic(['*']);
let model = dynamic(['*']);
let get_model = (Properties: dynamic) { iff(Properties["gen_ai.request.model"] == "", Properties["gen_ai.response.model"], Properties["gen_ai.request.model"]) };
let is_inference_call = (Properties: dynamic) {
    Properties["gen_ai.system"] != "" and Properties["gen_ai.operation.name"] in ("chat", "process_thread_run", "text_completion", "get_thread_run")
};
let filter_model_and_app = (Properties: dynamic, app_name: string) {
    ("*" in (model) or array_length(model) == 0 or get_model(Properties) in (model)) and
    ('*' in (application) or array_length(application) == 0 or app_name in (application))
};
let filter_inference_model_and_app = (Properties: dynamic, app_name: string) {
    is_inference_call(Properties) == true and filter_model_and_app(Properties, app_name) == true
};
let change_percent = (final: double, initial: double) {
    iff(initial == 0, iff(final == 0, real(0), real(+inf)), (final - initial) / initial * 100)
};
let get_event_name = (Properties: dynamic, message: string) {
    iff(Properties["event.name"] == "", message, Properties["event.name"])
};
let get_evaluator_name = (Properties: dynamic, event_name: string) {
    iff(Properties["gen_ai.evaluator.name"] == "", split(event_name, ".")[2], tostring(Properties["gen_ai.evaluator.name"]))
};
let get_response_id = (Properties: dynamic) {
    iff(
        Properties["gen_ai.response.id"] == "",
        iff(Properties["gen_ai.thread.run.id"] == "", "", strcat(tostring(Properties["gen_ai.thread.id"]), "/", tostring(Properties["gen_ai.thread.run.id"]))),
        tostring(Properties["gen_ai.response.id"])
    )
};
let inference_calls =
    union
        (AppDependencies
         | where filter_inference_model_and_app(Properties, AppRoleName) == true
         | where Properties["gen_ai.operation.name"] != "get_thread_run"
         | project response_id=get_response_id(Properties), model=tostring(get_model(Properties))),
        (AppDependencies
         | where filter_inference_model_and_app(Properties, AppRoleName) == true
         | where Properties["gen_ai.operation.name"] == "get_thread_run"
         | summarize arg_max(TimeGenerated, *) by tostring(Properties["gen_ai.thread.run.id"])
         | project response_id=get_response_id(Properties), model=tostring(get_model(Properties)));
let evals = AppTraces
    | where filter_model_and_app(Properties, AppRoleName)
    | extend event_name = get_event_name(Properties, Message)
    | where event_name startswith "gen_ai.evaluation"
    | extend
        evaluator_name = get_evaluator_name(Properties, event_name),
        score = todouble(Properties["gen_ai.evaluation.score"]),
        response_id=get_response_id(Properties);
let current_scores = evals
    | where TimeGenerated > ago(period)
    | join kind=leftouter inference_calls on response_id
    | summarize current_score=avg(score) by evaluator_name;
let previous_scores = evals
    | where TimeGenerated between(ago(2 * period) .. ago(period))
    | join kind=leftouter inference_calls on response_id
    | summarize previous_score=avg(score) by evaluator_name;
current_scores
| join kind=inner previous_scores on evaluator_name
| extend pct_change = change_percent(current_score, previous_score)
| project evaluator_name, pct_change
```

**Alert config:** Aggregation = Minimum, Measure = `pct_change`, Operator = LessThan, Threshold = -20%, Dimension = `evaluator_name`

---

## 4. Inference Request Failure Rate (LAW)

```kql
let application = dynamic(['*']);
let model = dynamic(['*']);
let get_model = (Properties: dynamic) { iff(Properties["gen_ai.request.model"] == "", Properties["gen_ai.response.model"], Properties["gen_ai.request.model"]) };
let is_inference_call = (Properties: dynamic) {
    Properties["gen_ai.system"] != "" and Properties["gen_ai.operation.name"] in ("chat", "process_thread_run", "text_completion", "get_thread_run")
};
let filter_inference_model_and_app = (Properties: dynamic, app_name: string) {
    is_inference_call(Properties) == true and
    ("*" in (model) or array_length(model) == 0 or get_model(Properties) in (model)) and
    ('*' in (application) or array_length(application) == 0 or app_name in (application))
};
let base_data = AppDependencies
    | where filter_inference_model_and_app(Properties, AppRoleName) == true;
let deduped_data =
    union
        (base_data | where Properties["gen_ai.operation.name"] != "get_thread_run"),
        (base_data | where Properties["gen_ai.operation.name"] == "get_thread_run"
         | summarize arg_max(TimeGenerated, *) by tostring(Properties["gen_ai.thread.run.id"]));
deduped_data
| where filter_inference_model_and_app(Properties, AppRoleName) == true
| summarize total = count(), failures = countif(Success == false)
| extend failure_rate = iff(total == 0, 0.0, todouble(failures) / todouble(total) * 100)
| project failure_rate
```

**Alert config:** Aggregation = Maximum, Measure = `failure_rate`, Operator = GreaterThan, Threshold = 10%

---

# Additional Best-Practice Metrics for GenAI Monitoring

The four alerts above cover the core pillars (cost, quality floor, quality trend, reliability). The metrics below are recommended supplementary signals that can also be expressed in KQL against the same App Insights / LAW data sources.

## Metric Catalog

| # | Metric | Type | Pillar | Why it matters | Suggested threshold |
|---|---|---|---|---|---|
| 1 | **End-to-end latency (P95)** | Performance | Reliability / UX | Slow responses harm UX even when calls succeed | > 5s P95 over 30 min |
| 2 | **Throttling rate (HTTP 429)** | Reliability | Capacity | Distinguishes rate-limit hits from generic failures | > 1% of requests |
| 3 | **Tool/function call error rate** | Reliability | Agent behavior | Tool failures break agent workflows | > 5% of tool invocations |
| 4 | **Cost per session/conversation** | Cost | Budget | Detects expensive runaway conversations | > $0.50 per session |
| 5 | **Average tokens per request** | Efficiency | Cost / Prompt design | Sudden growth indicates prompt bloat or context inflation | +30% week-over-week |
| 6 | **Request volume (RPM)** | Capacity | Scaling | Catches traffic spikes/drops indicating issues | ±50% from baseline |
| 7 | **Safety evaluator violations** | Safety | Compliance | Zero-tolerance signals (violence, hate, self-harm, etc.) | Any occurrence |
| 8 | **Groundedness score** | Quality | Hallucination control | Specific evaluator that detects RAG/citation failures | Avg < 4.0 |
| 9 | **Empty / refusal response rate** | Quality | UX | High refusal rate indicates over-restrictive prompts or content filter issues | > 5% of responses |
| 10 | **Thread run duration (P95)** | Performance | Agent behavior | Long-running threads suggest agent loops | > 60s P95 |
| 11 | **Active threads / concurrent sessions** | Capacity | Scaling | Indicator of system load | Workload-specific |
| 12 | **Model deployment distribution** | Cost / Routing | Governance | Detects unexpected use of expensive models | Workload-specific |
| 13 | **Cache hit rate (semantic cache)** | Efficiency | Cost | Low hit rate means missed cost-saving opportunities | < 30% |
| 14 | **Time-to-first-token (TTFT)** | Performance | UX | Streaming UX metric | > 2s P95 |
| 15 | **Daily / monthly token budget burn** | Cost | Budget | Forecasts overspend before month-end | > 80% of budget |

---

## Sample KQL Snippets

### 1. End-to-end latency (P95) — App Insights

```kql
dependencies
| where customDimensions["gen_ai.system"] != ""
| where customDimensions["gen_ai.operation.name"] in ("chat", "process_thread_run", "text_completion")
| summarize p95_latency_ms = percentile(duration, 95) by bin(timestamp, 30m)
```

### 2. Throttling rate (HTTP 429)

```kql
dependencies
| where customDimensions["gen_ai.system"] != ""
| summarize total = count(), throttled = countif(resultCode == "429")
| extend throttle_rate_pct = iff(total == 0, 0.0, todouble(throttled) / todouble(total) * 100)
| project throttle_rate_pct
```

### 3. Tool/function call error rate

```kql
dependencies
| where customDimensions["gen_ai.operation.name"] == "execute_tool"
| summarize total = count(), failures = countif(success == false)
| extend tool_failure_rate = iff(total == 0, 0.0, todouble(failures) / todouble(total) * 100)
| project tool_failure_rate
```

### 4. Cost per session (assumes pricing per 1K tokens)

```kql
let input_price_per_1k = 0.0025;   // GPT-4o input pricing example
let output_price_per_1k = 0.01;    // GPT-4o output pricing example
dependencies
| where customDimensions["gen_ai.system"] != ""
| extend
    thread_id = tostring(customDimensions["gen_ai.thread.id"]),
    input_tokens = toint(customDimensions["gen_ai.usage.input_tokens"]),
    output_tokens = toint(customDimensions["gen_ai.usage.output_tokens"])
| summarize
    session_cost_usd = sum(input_tokens) / 1000.0 * input_price_per_1k
                     + sum(output_tokens) / 1000.0 * output_price_per_1k
    by thread_id
| summarize max_session_cost = max(session_cost_usd), avg_session_cost = avg(session_cost_usd)
```

### 5. Average tokens per request

```kql
dependencies
| where customDimensions["gen_ai.system"] != ""
| extend total_tokens = toint(customDimensions["gen_ai.usage.input_tokens"]) + toint(customDimensions["gen_ai.usage.output_tokens"])
| summarize avg_tokens_per_request = avg(total_tokens) by bin(timestamp, 1h)
```

### 6. Request volume per minute

```kql
dependencies
| where customDimensions["gen_ai.system"] != ""
| where customDimensions["gen_ai.operation.name"] in ("chat", "process_thread_run", "text_completion")
| summarize rpm = count() by bin(timestamp, 1m)
```

### 7. Safety evaluator violations (zero-tolerance alert)

```kql
traces
| extend event_name = iff(customDimensions["event.name"] == "", message, customDimensions["event.name"])
| where event_name startswith "gen_ai.evaluation"
| extend
    evaluator_id = tostring(customDimensions["gen_ai.evaluator.id"]),
    score = todouble(customDimensions["gen_ai.evaluation.score"])
| where evaluator_id in~ (
    "azureai://built-in/evaluators/violence",
    "azureai://built-in/evaluators/hate_unfairness",
    "azureai://built-in/evaluators/self_harm",
    "azureai://built-in/evaluators/sexual",
    "azureai://built-in/evaluators/indirect_attack",
    "azureai://built-in/evaluators/code_vulnerability"
  )
| where score >= 3   // Azure safety evaluators: 0=safe, higher=worse
| count
```

**Alert config:** Aggregation = Total, Operator = GreaterThan, Threshold = 0, Severity = 0 (Critical)

### 8. Groundedness score (specific evaluator)

```kql
traces
| extend event_name = iff(customDimensions["event.name"] == "", message, customDimensions["event.name"])
| where event_name startswith "gen_ai.evaluation"
| extend
    evaluator_name = tostring(customDimensions["gen_ai.evaluator.name"]),
    score = todouble(customDimensions["gen_ai.evaluation.score"])
| where evaluator_name == "groundedness"
| summarize avg_groundedness = avg(score)
```

### 9. Empty / refusal response rate

```kql
dependencies
| where customDimensions["gen_ai.system"] != ""
| extend output_tokens = toint(customDimensions["gen_ai.usage.output_tokens"])
| extend finish_reason = tostring(customDimensions["gen_ai.response.finish_reasons"])
| summarize
    total = count(),
    empty_or_refused = countif(output_tokens < 5 or finish_reason has "content_filter")
| extend refusal_rate_pct = iff(total == 0, 0.0, todouble(empty_or_refused) / todouble(total) * 100)
| project refusal_rate_pct
```

### 10. Thread run duration (P95) — agent loop detector

```kql
dependencies
| where customDimensions["gen_ai.operation.name"] == "process_thread_run"
| summarize p95_run_duration_s = percentile(duration / 1000.0, 95) by bin(timestamp, 30m)
```

### 11. Active threads / concurrent sessions

```kql
dependencies
| where customDimensions["gen_ai.system"] != ""
| extend thread_id = tostring(customDimensions["gen_ai.thread.id"])
| where isnotempty(thread_id)
| summarize active_threads = dcount(thread_id) by bin(timestamp, 5m)
```

### 12. Model deployment distribution

```kql
dependencies
| where customDimensions["gen_ai.system"] != ""
| extend model = tostring(iff(customDimensions["gen_ai.request.model"] == "", customDimensions["gen_ai.response.model"], customDimensions["gen_ai.request.model"]))
| summarize call_count = count() by model, bin(timestamp, 1h)
| order by timestamp desc, call_count desc
```

### 13. Daily token budget burn

```kql
let daily_budget_tokens = 5000000;   // adjust to your daily budget
dependencies
| where customDimensions["gen_ai.system"] != ""
| where timestamp > startofday(now())
| extend total_tokens = toint(customDimensions["gen_ai.usage.input_tokens"]) + toint(customDimensions["gen_ai.usage.output_tokens"])
| summarize tokens_today = sum(total_tokens)
| extend budget_burn_pct = todouble(tokens_today) / todouble(daily_budget_tokens) * 100
| project tokens_today, budget_burn_pct
```

**Alert config:** Aggregation = Maximum, Measure = `budget_burn_pct`, Operator = GreaterThan, Threshold = 80

---

## Recommended Implementation Priority

**Phase 1 — Already implemented (4 core alerts):**
- Token Usage, Quality Absolute, Quality Regression, Failure Rate

**Phase 2 — Add immediately for production:**
- Safety evaluator violations (zero-tolerance, severity 0)
- Throttling rate (HTTP 429) — distinguishes capacity issues
- End-to-end latency P95 — UX guardrail
- Daily token budget burn — financial guardrail

**Phase 3 — Add as workload matures:**
- Cost per session
- Tool/function call error rate
- Groundedness score (if using RAG)
- Refusal rate

**Phase 4 — Optimization signals (dashboards, not alerts):**
- Average tokens per request
- Model deployment distribution
- Cache hit rate
- Active threads / concurrent sessions

---

## Notes

- All snippets use the App Insights schema. To convert to LAW schema, apply the same mapping shown earlier (`dependencies` → `AppDependencies`, `customDimensions` → `Properties`, etc.).
- Pricing values in cost queries are examples — substitute current Azure OpenAI pricing for your model and region.
- Safety evaluator scoring direction varies by evaluator family; verify the score scale and threshold for your specific evaluators before deploying as alerts.
