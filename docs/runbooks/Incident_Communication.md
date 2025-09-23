# 8. Incident Communication Runbook – Example

**Scenario:**  
An alert indicates degraded performance in the Iris classifier (`iris_classifier_v3`). The oncall engineer needs to communicate status, updates, and resolution across teams.

---

**Objective:**  
Ensure clear, timely, and consistent communication during ML incidents so stakeholders remain informed and actions are coordinated.

---

## Steps (Example)

1. **Acknowledge the alert**  
   - Confirm receipt in PagerDuty or monitoring system.  
   - Post in incident Slack/Teams channel:  
     - *"Incident started: Iris classifier latency exceeding threshold. Investigation in progress."*  

2. **Assign roles**  
   - **Incident Commander (IC):** leads resolution effort.  
   - **Communications Lead (CL):** posts updates to stakeholders.  
   - **Resolver(s):** investigate technical issue.  

3. **Open an incident bridge**  
   - Create a Zoom/Meet bridge if multiple teams involved.  
   - Share link in the incident channel.  

4. **Provide regular updates**  
   - Post updates every 30 minutes or agreed cadence.  
   - Include: current status, next steps, estimated time to resolution.  
   - Example: *"We identified a corrupted dataset as root cause. Working on backfill. Next update in 30 mins."*  

5. **Escalate if necessary**  
   - Involve Data Engineering, DevOps, or Security based on root cause.  
   - Document who was paged and why.  

6. **Communicate resolution**  
   - Post confirmation once incident is resolved:  
     - *"Incident resolved: Iris classifier restored. Latency back within thresholds."*  

7. **Close the loop**  
   - File a post-mortem ticket with root cause, resolution, and follow-up actions.  
   - Share summary with stakeholders.  

---

## Troubleshooting (Example Issues)

- **No updates being posted:** assign Communications Lead explicitly.  
- **Stakeholder confusion:** provide plain-language updates, avoid jargon.  
- **Duplicate channels or bridges:** consolidate into one primary communication thread.  

---

## Contact Points

- **Primary:** Incident Commander (appointed per rotation)  
- **Secondary:** Team leads for ML, Data Engineering, and DevOps  

---

## Acceptance Criteria

- Incident acknowledged and communicated promptly.  
- Roles assigned (IC, CL, resolvers).  
- Stakeholders receive regular updates until closure.  
- Resolution and root cause documented in post-mortem.  
