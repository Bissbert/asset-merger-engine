# Scenarios and Use Cases

## Table of Contents

1. [Common Scenarios](#common-scenarios)
2. [Production Use Cases](#production-use-cases)
3. [Automation Examples](#automation-examples)
4. [Integration Patterns](#integration-patterns)
5. [Advanced Configurations](#advanced-configurations)
6. [Troubleshooting Scenarios](#troubleshooting-scenarios)

---

## Common Scenarios

### Scenario 1: Daily Synchronization

**Goal**: Synchronize all production servers daily at 2 AM

**Implementation**:
```bash
#!/bin/bash
# /etc/cron.daily/topdesk-zbx-sync.sh

# Configuration
export CONFIG_FILE="/etc/asset-merger-engine/production.conf"
export LOG_FILE="/var/log/merger/daily-sync-$(date +%Y%m%d).log"

# Lock file to prevent concurrent runs
LOCK_FILE="/var/run/merger-daily.lock"

# Check for existing lock
if [ -f "$LOCK_FILE" ]; then
    echo "Previous sync still running, exiting"
    exit 1
fi

# Create lock
touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Run synchronization
/opt/asset-merger-engine/bin/merger.sh \
    --config "$CONFIG_FILE" \
    --log "$LOG_FILE" \
    sync \
    --group "Production" \
    --auto \
    --batch-size 50

# Check result
if [ $? -eq 0 ]; then
    # Success - send summary
    /opt/asset-merger-engine/bin/merger.sh report \
        --format text | \
        mail -s "Daily Sync Success" ops@example.com
else
    # Failure - send alert
    tail -100 "$LOG_FILE" | \
        mail -s "Daily Sync FAILED" ops@example.com
fi
```

**Crontab Entry**:
```cron
0 2 * * * /etc/cron.daily/topdesk-zbx-sync.sh
```

### Scenario 2: New Server Onboarding

**Goal**: Automatically add new Zabbix hosts to Topdesk

**Workflow**:
```bash
#!/bin/bash
# onboard-new-servers.sh

# Get servers added in last 24 hours
NEW_SERVERS=$(zbx-cli hosts-list --created-after "24 hours ago" | jq -r '.[].host')

if [ -z "$NEW_SERVERS" ]; then
    echo "No new servers found"
    exit 0
fi

# Create temporary filter
echo "$NEW_SERVERS" > /tmp/new-servers.txt

# Fetch only new servers
/opt/merger/bin/merger.sh fetch \
    --host-file /tmp/new-servers.txt \
    --output /tmp/new-servers-data.json

# Create assets in Topdesk
/opt/merger/bin/merger.sh apply \
    --input /tmp/new-servers-data.json \
    --strategy create \
    --no-confirm

# Cleanup
rm -f /tmp/new-servers.txt /tmp/new-servers-data.json
```

### Scenario 3: Emergency Update

**Goal**: Quickly update critical server information after infrastructure change

**Interactive Process**:
```bash
# 1. Fetch specific servers
./bin/merger.sh fetch --tag "critical" --group "Infrastructure"

# 2. Review differences interactively
./bin/merger.sh diff --format table

# 3. Select changes via TUI
./bin/merger.sh tui

# 4. Apply with confirmation
./bin/merger.sh apply --confirm

# 5. Verify changes
topdesk assets-search "critical" | jq '.[] | {name, ip_address, location}'
```

### Scenario 4: Audit Compliance

**Goal**: Generate monthly compliance report showing sync status

**Script**:
```bash
#!/bin/bash
# monthly-audit.sh

MONTH=$(date +%Y-%m)
REPORT_DIR="/var/reports/merger/$MONTH"
mkdir -p "$REPORT_DIR"

# Full fetch without filters
echo "Fetching all assets..."
./bin/merger.sh fetch --all

# Generate comprehensive diff
echo "Analyzing differences..."
./bin/merger.sh diff \
    --fields "all" \
    --format json \
    --output "$REPORT_DIR/differences.json"

# Create audit report
cat > "$REPORT_DIR/audit-report.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Audit Report - $MONTH</title>
    <style>
        body { font-family: Arial, sans-serif; }
        .summary { background: #f0f0f0; padding: 15px; }
        .match { color: green; }
        .mismatch { color: red; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; }
    </style>
</head>
<body>
    <h1>Asset Synchronization Audit - $MONTH</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Report generated: $(date)</p>
EOF

# Add statistics
STATS=$(jq '.summary' "$REPORT_DIR/differences.json")
echo "<pre>$STATS</pre>" >> "$REPORT_DIR/audit-report.html"

# Add mismatches
echo "<h2>Mismatched Assets</h2>" >> "$REPORT_DIR/audit-report.html"
echo "<table>" >> "$REPORT_DIR/audit-report.html"
echo "<tr><th>Asset</th><th>Field</th><th>Zabbix</th><th>Topdesk</th></tr>" >> "$REPORT_DIR/audit-report.html"

jq -r '.matched_assets[] |
    .hostname as $host |
    .differences |
    to_entries[] |
    "<tr><td>\($host)</td><td>\(.key)</td><td>\(.value.zabbix)</td><td>\(.value.topdesk)</td></tr>"' \
    "$REPORT_DIR/differences.json" >> "$REPORT_DIR/audit-report.html"

echo "</table></body></html>" >> "$REPORT_DIR/audit-report.html"

# Send to compliance team
mail -a "Content-Type: text/html" \
     -s "Monthly Audit Report - $MONTH" \
     compliance@example.com < "$REPORT_DIR/audit-report.html"
```

---

## Production Use Cases

### Use Case 1: Multi-Environment Synchronization

**Scenario**: Different sync strategies for Production, Staging, and Development

**Configuration Files**:

```bash
# /etc/merger/profiles/production.conf
MERGE_STRATEGY="update"        # Only update, never create/delete
CONFLICT_RESOLUTION="topdesk"  # Topdesk is source of truth
VALIDATE_CRITICAL="true"        # Strict validation
NOTIFY_ON_ERROR="true"
BATCH_SIZE="25"                # Careful, small batches
REQUIRE_APPROVAL="true"        # Manual approval required

# /etc/merger/profiles/staging.conf
MERGE_STRATEGY="sync"          # Full sync
CONFLICT_RESOLUTION="zabbix"   # Zabbix is source of truth
VALIDATE_CRITICAL="false"      # Relaxed validation
NOTIFY_ON_ERROR="false"
BATCH_SIZE="100"               # Larger batches
REQUIRE_APPROVAL="false"       # Automatic

# /etc/merger/profiles/development.conf
MERGE_STRATEGY="sync"          # Full sync
CONFLICT_RESOLUTION="newest"   # Use most recent
VALIDATE_CRITICAL="false"      # Minimal validation
BATCH_SIZE="500"               # Maximum speed
DRY_RUN="true"                # Always dry-run first
```

**Execution**:
```bash
# Production sync (careful)
./bin/merger.sh --profile production sync

# Staging sync (automated)
./bin/merger.sh --profile staging sync --auto

# Development sync (test mode)
./bin/merger.sh --profile development sync --dry-run
```

### Use Case 2: Disaster Recovery

**Scenario**: Restore Topdesk assets from Zabbix after data loss

```bash
#!/bin/bash
# disaster-recovery.sh

echo "DISASTER RECOVERY MODE"
echo "====================="

# 1. Backup current state (if any)
echo "Creating backup..."
topdesk assets > /backup/topdesk-pre-recovery-$(date +%Y%m%d-%H%M%S).json

# 2. Fetch complete Zabbix inventory
echo "Fetching Zabbix inventory..."
./bin/merger.sh fetch --all --no-cache

# 3. Validate Zabbix data
echo "Validating source data..."
python3 lib/validator.py \
    --input output/zabbix_assets.json \
    --strict \
    --output validation-report.json

if [ $? -ne 0 ]; then
    echo "ERROR: Source data validation failed"
    exit 1
fi

# 4. Create recovery changeset
echo "Creating recovery plan..."
./bin/merger.sh diff \
    --strategy "zabbix-only" \
    --output recovery-plan.json

# 5. Review recovery plan
echo "Assets to recover: $(jq '.summary.total' recovery-plan.json)"
read -p "Continue with recovery? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Recovery cancelled"
    exit 0
fi

# 6. Apply recovery
echo "Applying recovery..."
./bin/merger.sh apply \
    --input recovery-plan.json \
    --strategy create \
    --force \
    --batch-size 10 \
    --retry-failed 5

# 7. Verification
echo "Verifying recovery..."
./bin/merger.sh validate --post-recovery

echo "Recovery complete!"
```

### Use Case 3: Selective Field Updates

**Scenario**: Update only specific fields across all assets

```bash
#!/bin/bash
# update-locations.sh
# Update location field for relocated datacenter

# Define field mapping
cat > /tmp/location-mapping.json << EOF
{
  "field": "location",
  "mappings": {
    "DC-Old-Rack-A": "DC-New-Rack-1",
    "DC-Old-Rack-B": "DC-New-Rack-2",
    "DC-Old-Rack-C": "DC-New-Rack-3"
  }
}
EOF

# Fetch affected assets
./bin/merger.sh fetch \
    --filter "location:DC-Old-*"

# Apply specific field update
python3 << EOF
import json

# Load data
with open('output/zabbix_assets.json') as f:
    assets = json.load(f)

with open('/tmp/location-mapping.json') as f:
    mapping = json.load(f)

# Create update queue
updates = []
for asset in assets:
    old_location = asset.get('inventory', {}).get('location')
    if old_location in mapping['mappings']:
        updates.append({
            'asset_id': asset['hostid'],
            'field': 'location',
            'old_value': old_location,
            'new_value': mapping['mappings'][old_location]
        })

# Save update queue
with open('output/apply/location-updates.json', 'w') as f:
    json.dump(updates, f, indent=2)

print(f"Prepared {len(updates)} location updates")
EOF

# Apply updates
./bin/merger.sh apply \
    --queue output/apply/location-updates.json \
    --confirm
```

### Use Case 4: Incremental Synchronization

**Scenario**: Sync only changed items since last run

```bash
#!/bin/bash
# incremental-sync.sh

LAST_SYNC_FILE="/var/lib/merger/last-sync-timestamp"
CURRENT_TIME=$(date -Iseconds)

# Get last sync time
if [ -f "$LAST_SYNC_FILE" ]; then
    LAST_SYNC=$(cat "$LAST_SYNC_FILE")
    echo "Last sync: $LAST_SYNC"
else
    # First run - sync everything
    LAST_SYNC="1970-01-01T00:00:00Z"
    echo "First run - full sync"
fi

# Fetch changes from Zabbix
echo "Fetching changes since $LAST_SYNC..."

# Use Zabbix API to get recently modified hosts
zbx-cli call host.get "{
    \"output\": \"extend\",
    \"selectInventory\": \"extend\",
    \"filter\": {
        \"lastchange\": {
            \"\$gte\": \"$(date -d "$LAST_SYNC" +%s)\"
        }
    }
}" > output/zabbix_changes.json

# Check if there are changes
CHANGE_COUNT=$(jq 'length' output/zabbix_changes.json)

if [ "$CHANGE_COUNT" -eq 0 ]; then
    echo "No changes detected"
    echo "$CURRENT_TIME" > "$LAST_SYNC_FILE"
    exit 0
fi

echo "Found $CHANGE_COUNT changed assets"

# Process changes
./bin/merger.sh sync \
    --input output/zabbix_changes.json \
    --strategy update

# Update timestamp on success
if [ $? -eq 0 ]; then
    echo "$CURRENT_TIME" > "$LAST_SYNC_FILE"
    echo "Incremental sync completed"
else
    echo "Sync failed - timestamp not updated"
    exit 1
fi
```

---

## Automation Examples

### Example 1: CI/CD Integration

**Goal**: Validate asset data in CI pipeline

`.gitlab-ci.yml`:
```yaml
stages:
  - validate
  - sync
  - report

validate_assets:
  stage: validate
  script:
    - apt-get update && apt-get install -y jq curl python3
    - ./bin/merger.sh validate --config ci/test.conf
    - ./bin/merger.sh fetch --dry-run
    - python3 lib/validator.py --strict --input test/fixtures/*.json
  only:
    - merge_requests

sync_staging:
  stage: sync
  script:
    - ./bin/merger.sh --profile staging sync --auto
  environment:
    name: staging
  only:
    - main

generate_report:
  stage: report
  script:
    - ./bin/merger.sh report --format html --output public/
  artifacts:
    paths:
      - public/
  only:
    - main
```

### Example 2: Slack Notifications

**Goal**: Send sync results to Slack

```bash
#!/bin/bash
# notify-slack.sh

SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ"

# Run sync and capture output
SYNC_OUTPUT=$(./bin/merger.sh sync --auto 2>&1)
SYNC_RESULT=$?

# Parse results
if [ -f "output/apply/results.json" ]; then
    STATS=$(jq '.summary' output/apply/results.json)
    SUCCESS=$(echo "$STATS" | jq '.successful')
    FAILED=$(echo "$STATS" | jq '.failed')
else
    SUCCESS=0
    FAILED=0
fi

# Determine status emoji
if [ $SYNC_RESULT -eq 0 ]; then
    STATUS_EMOJI=":white_check_mark:"
    STATUS_TEXT="SUCCESS"
    COLOR="good"
else
    STATUS_EMOJI=":x:"
    STATUS_TEXT="FAILED"
    COLOR="danger"
fi

# Create Slack payload
cat > /tmp/slack-payload.json << EOF
{
  "text": "${STATUS_EMOJI} Asset Sync ${STATUS_TEXT}",
  "attachments": [
    {
      "color": "${COLOR}",
      "fields": [
        {
          "title": "Successful Updates",
          "value": "${SUCCESS}",
          "short": true
        },
        {
          "title": "Failed Updates",
          "value": "${FAILED}",
          "short": true
        },
        {
          "title": "Timestamp",
          "value": "$(date -Iseconds)",
          "short": false
        }
      ]
    }
  ]
}
EOF

# Send to Slack
curl -X POST -H 'Content-type: application/json' \
    --data @/tmp/slack-payload.json \
    "$SLACK_WEBHOOK_URL"
```

### Example 3: Monitoring Integration

**Goal**: Export metrics to Prometheus

```python
#!/usr/bin/env python3
# export-metrics.py

import json
import time
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway

# Load sync results
with open('output/apply/results.json') as f:
    results = json.load(f)

# Create metrics
registry = CollectorRegistry()

sync_duration = Gauge('merger_sync_duration_seconds',
                     'Duration of sync operation',
                     registry=registry)
sync_success = Gauge('merger_sync_success_total',
                    'Number of successful updates',
                    registry=registry)
sync_failed = Gauge('merger_sync_failed_total',
                   'Number of failed updates',
                   registry=registry)

# Set values
sync_duration.set(results.get('duration_seconds', 0))
sync_success.set(results['summary']['successful'])
sync_failed.set(results['summary']['failed'])

# Push to Prometheus Pushgateway
push_to_gateway('prometheus-pushgateway:9091',
                job='merger_sync',
                registry=registry)

print("Metrics exported to Prometheus")
```

### Example 4: Auto-remediation

**Goal**: Automatically fix common issues

```bash
#!/bin/bash
# auto-remediate.sh

# Common fixes mapping
declare -A FIXES=(
    ["invalid_ip"]="clear_ip_field"
    ["missing_location"]="set_default_location"
    ["duplicate_hostname"]="append_suffix"
)

# Run validation
python3 lib/validator.py \
    --input output/zabbix_assets.json \
    --output validation-errors.json

# Parse errors
ERRORS=$(jq -r '.validation_errors[].error' validation-errors.json | sort -u)

for error in $ERRORS; do
    if [ -n "${FIXES[$error]}" ]; then
        echo "Auto-fixing: $error"

        case "${FIXES[$error]}" in
            "clear_ip_field")
                jq '.[] | select(.ip_address | test("^[^0-9]")) | .ip_address = ""' \
                    output/zabbix_assets.json > output/fixed.json
                ;;
            "set_default_location")
                jq '.[] | .location //= "Unknown"' \
                    output/zabbix_assets.json > output/fixed.json
                ;;
            "append_suffix")
                jq '.[] | .hostname = .hostname + "-" + .hostid' \
                    output/zabbix_assets.json > output/fixed.json
                ;;
        esac

        # Replace with fixed version
        mv output/fixed.json output/zabbix_assets.json
    else
        echo "No auto-fix available for: $error"
    fi
done

echo "Auto-remediation complete"
```

---

## Integration Patterns

### Pattern 1: Event-Driven Sync

**Using Zabbix Webhooks**:

```python
# zabbix-webhook.py
from flask import Flask, request
import subprocess
import json

app = Flask(__name__)

@app.route('/webhook/host-added', methods=['POST'])
def host_added():
    """Triggered when new host added to Zabbix"""
    data = request.json
    host_id = data['hostid']

    # Trigger sync for new host
    result = subprocess.run([
        '/opt/merger/bin/merger.sh',
        'fetch',
        '--host-id', host_id
    ], capture_output=True)

    if result.returncode == 0:
        subprocess.run([
            '/opt/merger/bin/merger.sh',
            'apply',
            '--strategy', 'create',
            '--auto'
        ])

    return {'status': 'processed'}

@app.route('/webhook/host-updated', methods=['POST'])
def host_updated():
    """Triggered when host updated in Zabbix"""
    data = request.json
    host_id = data['hostid']
    fields = data.get('changed_fields', [])

    # Sync specific fields
    result = subprocess.run([
        '/opt/merger/bin/merger.sh',
        'sync',
        '--host-id', host_id,
        '--fields', ','.join(fields),
        '--auto'
    ])

    return {'status': 'processed'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### Pattern 2: Service Mesh Integration

**Kubernetes CronJob**:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: asset-sync
  namespace: operations
spec:
  schedule: "0 */4 * * *"  # Every 4 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: merger
            image: company/asset-merger-engine:latest
            env:
            - name: CONFIG_FILE
              value: /config/merger.conf
            - name: LOG_LEVEL
              value: INFO
            volumeMounts:
            - name: config
              mountPath: /config
              readOnly: true
            - name: cache
              mountPath: /var/cache/merger
            command:
            - /bin/sh
            - -c
            - |
              /opt/merger/bin/merger.sh sync --auto
              # Export metrics
              curl -X POST http://metrics-collector:9090/metrics \
                -d @output/metrics.json
          volumes:
          - name: config
            configMap:
              name: merger-config
          - name: cache
            persistentVolumeClaim:
              claimName: merger-cache
          restartPolicy: OnFailure
```

### Pattern 3: Message Queue Integration

**RabbitMQ Consumer**:

```python
#!/usr/bin/env python3
# mq-consumer.py

import pika
import json
import subprocess

def process_sync_request(ch, method, properties, body):
    """Process sync request from queue"""
    try:
        message = json.loads(body)
        command = message.get('command', 'sync')
        options = message.get('options', {})

        # Build command
        cmd = ['/opt/merger/bin/merger.sh', command]
        for key, value in options.items():
            cmd.extend([f'--{key}', str(value)])

        # Execute
        result = subprocess.run(cmd, capture_output=True, text=True)

        # Send result to response queue
        response = {
            'status': 'success' if result.returncode == 0 else 'failed',
            'output': result.stdout,
            'error': result.stderr
        }

        ch.basic_publish(
            exchange='',
            routing_key='sync_responses',
            body=json.dumps(response)
        )

        ch.basic_ack(delivery_tag=method.delivery_tag)

    except Exception as e:
        print(f"Error processing message: {e}")
        ch.basic_nack(delivery_tag=method.delivery_tag)

# Connect to RabbitMQ
connection = pika.BlockingConnection(
    pika.ConnectionParameters('rabbitmq-server')
)
channel = connection.channel()

channel.queue_declare(queue='sync_requests', durable=True)
channel.queue_declare(queue='sync_responses', durable=True)

channel.basic_consume(
    queue='sync_requests',
    on_message_callback=process_sync_request
)

print("Waiting for sync requests...")
channel.start_consuming()
```

---

## Advanced Configurations

### Configuration 1: High-Availability Setup

```bash
# /etc/merger/ha.conf

# Primary/Secondary configuration
HA_MODE="active-standby"
HA_ROLE="${HA_ROLE:-primary}"  # Set by orchestrator
HA_PEER="merger-secondary.example.com"
HA_VIP="merger.example.com"  # Virtual IP

# State synchronization
STATE_SYNC="true"
STATE_SYNC_INTERVAL="60"  # seconds
STATE_DIR="/var/lib/merger/state"

# Distributed locking
USE_DISTRIBUTED_LOCK="true"
LOCK_BACKEND="redis"
REDIS_URL="redis://redis-cluster:6379/0"
LOCK_TTL="300"  # 5 minutes

# Failover configuration
FAILOVER_TIMEOUT="30"
HEALTH_CHECK_INTERVAL="10"
MAX_FAILED_CHECKS="3"

# Load balancing for API calls
ZABBIX_URLS=(
    "https://zabbix1.example.com/api"
    "https://zabbix2.example.com/api"
)
TOPDESK_URLS=(
    "https://topdesk1.example.com/api"
    "https://topdesk2.example.com/api"
)

# Replication
REPLICATE_CACHE="true"
REPLICATE_LOGS="true"
REPLICATION_LAG_THRESHOLD="60"  # seconds
```

### Configuration 2: Multi-Tenant Setup

```bash
# /etc/merger/tenants/tenant1.conf

# Tenant identification
TENANT_ID="tenant1"
TENANT_NAME="Customer A"

# Tenant-specific Zabbix
ZABBIX_URL="https://tenant1.zabbix.local/api"
ZABBIX_USER="tenant1_api"
ZABBIX_GROUP_FILTER="Tenant1/*"

# Tenant-specific Topdesk
TOPDESK_URL="https://customer-a.topdesk.com/api"
TOPDESK_BRANCH="Customer-A"

# Isolation
DATA_DIR="/var/lib/merger/tenants/tenant1"
LOG_FILE="/var/log/merger/tenant1.log"
CACHE_PREFIX="tenant1_"

# Quotas
MAX_ASSETS="10000"
MAX_API_CALLS_PER_HOUR="1000"
MAX_BATCH_SIZE="50"
```

### Configuration 3: Performance Tuning

```bash
# /etc/merger/performance.conf

# Connection pooling
CONNECTION_POOL_SIZE="10"
CONNECTION_TIMEOUT="5"
CONNECTION_RETRY="3"
KEEPALIVE="true"
KEEPALIVE_IDLE="60"

# Caching
CACHE_BACKEND="redis"  # memory|redis|disk
REDIS_CACHE_URL="redis://redis:6379/1"
CACHE_COMPRESSION="true"
CACHE_TTL_ZABBIX="300"  # 5 minutes
CACHE_TTL_TOPDESK="600"  # 10 minutes
CACHE_WARMUP="true"

# Batch processing
BATCH_SIZE="200"
PARALLEL_BATCHES="4"
BATCH_RETRY_DELAY="2"
BATCH_RETRY_BACKOFF="exponential"

# Memory management
MAX_MEMORY_MB="2048"
GC_THRESHOLD="1024"  # MB
STREAM_PROCESSING="true"  # For large datasets

# Database optimization (if using DB backend)
DB_CONNECTION_POOL="20"
DB_STATEMENT_CACHE="100"
DB_BATCH_INSERT="true"
DB_ASYNC_COMMIT="true"

# API optimization
API_COMPRESSION="gzip"
API_KEEPALIVE="true"
API_PIPELINE="true"  # HTTP/2 if supported
API_PREFETCH="true"  # Predictive fetching
```

---

## Troubleshooting Scenarios

### Scenario 1: Handling API Rate Limits

**Problem**: "429 Too Many Requests" errors

**Solution**:
```bash
#!/bin/bash
# rate-limit-handler.sh

# Exponential backoff implementation
retry_with_backoff() {
    local max_attempts=5
    local timeout=1
    local attempt=1
    local exitcode=0

    while [ $attempt -le $max_attempts ]; do
        # Try the command
        if "$@"; then
            return 0
        else
            exitcode=$?
        fi

        # Check if rate limited
        if [ $exitcode -eq 8 ]; then  # Rate limit error code
            echo "Rate limited, attempt $attempt/$max_attempts"
            sleep $timeout
            timeout=$((timeout * 2))
            attempt=$((attempt + 1))
        else
            # Other error, don't retry
            return $exitcode
        fi
    done

    echo "Max attempts reached"
    return $exitcode
}

# Use with merger
retry_with_backoff ./bin/merger.sh fetch --batch-size 10
```

### Scenario 2: Debugging Field Mapping Issues

**Problem**: Fields not mapping correctly

**Debug Process**:
```bash
#!/bin/bash
# debug-mappings.sh

# Enable debug mode
export DEBUG=1
export LOG_LEVEL=DEBUG

# Test with single asset
TEST_ASSET="web-server-01"

# Fetch single asset
echo "Fetching test asset..."
zbx-cli host-get "$TEST_ASSET" > test-zabbix.json
topdesk assets-get "$TEST_ASSET" > test-topdesk.json

# Test mapping
echo "Testing field mapping..."
python3 -c "
import json
from lib.sorter import AssetSorter

# Load test data
with open('test-zabbix.json') as f:
    zbx = json.load(f)
with open('test-topdesk.json') as f:
    td = json.load(f)

# Test mapping
sorter = AssetSorter({'debug': True})
mapped = sorter.map_fields(zbx, td)

# Show mapping
print('Field Mapping Results:')
print(json.dumps(mapped, indent=2))

# Show issues
issues = sorter.validate_mapping(mapped)
if issues:
    print('\\nMapping Issues:')
    for issue in issues:
        print(f'  - {issue}')
"
```

### Scenario 3: Handling Large Datasets

**Problem**: Memory exhaustion with 50,000+ assets

**Solution**:
```python
#!/usr/bin/env python3
# stream-processor.py

import json
import ijson  # Streaming JSON parser

def stream_process_assets(zabbix_file, topdesk_file, chunk_size=1000):
    """Process large datasets in chunks"""

    # Stream Zabbix data
    with open(zabbix_file, 'rb') as f:
        parser = ijson.items(f, 'item')
        chunk = []

        for item in parser:
            chunk.append(item)

            if len(chunk) >= chunk_size:
                # Process chunk
                process_chunk(chunk)
                chunk = []

        # Process remaining
        if chunk:
            process_chunk(chunk)

def process_chunk(assets):
    """Process a chunk of assets"""
    print(f"Processing {len(assets)} assets...")

    # Create temporary file for chunk
    chunk_file = f'/tmp/chunk_{hash(str(assets))}.json'
    with open(chunk_file, 'w') as f:
        json.dump(assets, f)

    # Process with merger
    subprocess.run([
        './bin/merger.sh',
        'apply',
        '--input', chunk_file,
        '--no-confirm'
    ])

    # Cleanup
    os.remove(chunk_file)

# Use streaming processor
stream_process_assets(
    'output/zabbix_assets.json',
    'output/topdesk_assets.json',
    chunk_size=500
)
```

### Scenario 4: Recovering from Partial Sync Failure

**Problem**: Sync failed halfway through

**Recovery Process**:
```bash
#!/bin/bash
# recover-partial-sync.sh

echo "Analyzing partial sync failure..."

# Check transaction log
TRANSACTION_LOG="/var/log/merger/transactions.log"
LAST_TRANSACTION=$(tail -1 "$TRANSACTION_LOG" | jq -r '.transaction_id')

echo "Last transaction: $LAST_TRANSACTION"

# Get completed operations
COMPLETED=$(grep "$LAST_TRANSACTION" "$TRANSACTION_LOG" | \
    jq -r 'select(.status=="success") | .asset_id')

# Get failed operations
FAILED=$(grep "$LAST_TRANSACTION" "$TRANSACTION_LOG" | \
    jq -r 'select(.status=="failed") | .asset_id')

# Save state
echo "$COMPLETED" > /tmp/completed-assets.txt
echo "$FAILED" > /tmp/failed-assets.txt

echo "Completed: $(wc -l < /tmp/completed-assets.txt) assets"
echo "Failed: $(wc -l < /tmp/failed-assets.txt) assets"

# Retry failed
if [ -s /tmp/failed-assets.txt ]; then
    echo "Retrying failed assets..."

    # Create retry queue
    jq --slurpfile failed /tmp/failed-assets.txt \
        '.changes[] | select(.asset_id | IN($failed[]))' \
        output/apply/queue.json > /tmp/retry-queue.json

    # Retry with increased timeout
    ./bin/merger.sh apply \
        --queue /tmp/retry-queue.json \
        --timeout 60 \
        --retry 5
fi

# Resume from checkpoint
REMAINING=$(jq --slurpfile completed /tmp/completed-assets.txt \
    '.changes[] | select(.asset_id | IN($completed[]) | not)' \
    output/apply/queue.json)

if [ -n "$REMAINING" ]; then
    echo "$REMAINING" > /tmp/remaining-queue.json
    echo "Resuming remaining assets..."

    ./bin/merger.sh apply \
        --queue /tmp/remaining-queue.json \
        --checkpoint
fi

echo "Recovery complete"
```

---

## Best Practices

### 1. Pre-Production Testing

Always test in non-production first:

```bash
# Test workflow
./bin/merger.sh --dry-run validate
./bin/merger.sh --dry-run fetch --limit 10
./bin/merger.sh --dry-run sync
```

### 2. Monitoring and Alerting

Set up comprehensive monitoring:

```bash
# Health check endpoint
curl -f http://localhost:8080/health || alert "Merger unhealthy"

# Log monitoring
tail -f /var/log/merger.log | grep ERROR | \
    while read line; do
        alert "Error detected: $line"
    done
```

### 3. Data Validation

Always validate before applying:

```bash
# Validation pipeline
./bin/merger.sh fetch && \
./bin/merger.sh validate --strict && \
./bin/merger.sh diff && \
./bin/merger.sh validate --changes && \
./bin/merger.sh apply
```

### 4. Backup and Recovery

Maintain backups:

```bash
# Backup before sync
topdesk assets > backup-$(date +%Y%m%d).json
./bin/merger.sh sync
# Keep backups for 30 days
find /backup -name "backup-*.json" -mtime +30 -delete
```

### 5. Documentation

Keep documentation updated:

```bash
# Generate documentation
./bin/merger.sh report --format markdown > docs/latest-sync.md
# Update README with latest config
./bin/merger.sh config show --markdown >> README.md
```

---

This documentation provides comprehensive scenarios, examples, and patterns for using the asset-merger-engine tool in production environments.