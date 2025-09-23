# ML Oncall Runbooks

## 1. Model Deployment Runbook
**Description:** Steps to safely deploy a new or updated ML model into production, verify its integrity, and roll back if issues arise.  
**Acceptance Criteria:**
- Model artifact integrity is validated.  
- Deployment environment configured (container, serverless, etc.).  
- Smoke/inference tests pass on gold cases.  
- Rollout strategy (canary, A/B) executed and validated.  
- Health checks confirm stability post-deployment.  
- Rollback plan documented and tested.  

---

## 2. Model Retraining and Update Runbook
**Description:** Process for retraining models with new data and updating the deployed version without regressions.  
**Acceptance Criteria:**
- New data sources identified and validated.  
- Training pipeline executes successfully (feature engineering → model training → validation).  
- Performance is compared against baselines and production metrics.  
- Retrained model is version-controlled.  
- Deployment follows the Model Deployment Runbook.  

---

## 3. Model Monitoring and Alerting Runbook
**Description:** Responding to alerts about data drift, performance degradation, or inference issues.  
**Acceptance Criteria:**
- Alert context (accuracy drop, latency, drift) investigated and documented.  
- Predictions and input data analyzed for anomalies.  
- Determination made whether retraining, re-engineering, or rollback is needed.  
- Findings and actions logged in incident tracker.  
- False positives and recurring alerts reviewed for long-term fixes.  

---

## 4. Data Pipeline Failure Runbook
**Description:** Steps to resolve failures in data pipelines that feed training or inference models.  
**Acceptance Criteria:**
- Failed component(s) identified via logs/alerts.  
- Root cause determined and documented.  
- Pipeline re-run or component repaired successfully.  
- Data integrity validated before downstream usage.  
- Status communicated to ML users and downstream teams.  

---

## 5. ML Infrastructure Scaling Runbook
**Description:** Scaling ML infrastructure to meet demand (e.g., inference load, training needs).  
**Acceptance Criteria:**
- Bottlenecks identified (CPU, GPU, memory, network, storage).  
- Scaling plan chosen (horizontal/vertical).  
- Scaling executed via infra-as-code or approved manual steps.  
- Resource utilization and model performance validated after scaling.  
- Resource cleanup plan defined to avoid unnecessary costs.  

---

## 6. Data Quality & Availability Runbook
**Description:** Handle situations where upstream data is delayed, missing, corrupted, or otherwise unusable.  
**Acceptance Criteria:**
- Data source health checks confirm root cause (delayed feed, schema change, corruption).  
- Missing/invalid data backfilled or substituted with fallback.  
- Escalation to upstream provider (internal/external) documented.  
- Model impact assessed (e.g., stop-gap mode vs. retraining delay).  
- Resolution and communication logged.  

---

## 7. Access & Permissions Runbook
**Description:** Steps to follow when ML engineers lose access to critical systems (S3, model registry, monitoring, secrets).  
**Acceptance Criteria:**
- Access issue confirmed (IAM, VPN, expired tokens, secrets).  
- Short-term workaround applied (temporary creds, assume-role).  
- Escalation path to security/infra followed if issue persists.  
- Incident documented with timelines.  
- Root cause (e.g., expired keys, role misconfig) fixed permanently.  

---

## 8. Incident Communication Runbook
**Description:** Defines who communicates during an incident, how updates are delivered, and when to escalate.  
**Acceptance Criteria:**
- PagerDuty/alert bridge opened promptly.  
- Roles assigned (incident commander, comms lead, resolver).  
- Updates provided at agreed cadence (e.g., every 30 mins).  
- Stakeholders notified via designated Slack/Teams channel.  
- Post-mortem ticket created after resolution.  
