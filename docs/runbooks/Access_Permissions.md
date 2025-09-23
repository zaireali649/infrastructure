# 7. Access & Permissions Runbook – Example

**Scenario:**  
An ML engineer cannot access the model registry, object storage, or monitoring dashboard required to deploy or debug the Iris classifier (`iris_classifier_v3`).

---

**Objective:**  
Resolve access and permission issues for ML systems quickly so oncall engineers can continue operations.

---

## Steps (Example)

1. **Confirm the issue**  
   - Attempt to access the resource (e.g., storage bucket, model registry, monitoring dashboard).  
   - Example: `AccessDenied` when retrieving `iris_classifier_v3.pkl` from storage.  

2. **Check authentication status**  
   - Verify login session, VPN connection, or token validity.  
   - Run a simple command to test (e.g., `ls s3://ml-models/iris/`).  

3. **Validate permissions**  
   - Confirm correct IAM role, group membership, or service account is in use.  
   - Example: role `ml-engineer-oncall` missing `read` permission for model registry.  

4. **Apply short-term workaround**  
   - Request temporary credentials or assume an alternate role (if approved).  
   - Example: use break-glass account to pull model artifact.  

5. **Escalate if unresolved**  
   - Open incident with Security/Infrastructure team.  
   - Provide details: resource, error message, affected role/account.  

6. **Document and fix root cause**  
   - If access expired, extend token lifetime or rotate keys.  
   - If role misconfigured, update policy with least-privilege fix.  
   - Confirm permanent resolution before closing ticket.  

---

## Troubleshooting (Example Issues)

- **Expired credentials:** refresh tokens or reauthenticate.  
- **Misconfigured role:** missing `s3:GetObject` or equivalent permission → update IAM policy.  
- **Network/VPN issues:** verify connectivity to restricted environment.  

---

## Contact Points

- **Primary:** ML Engineering oncall  
- **Secondary:** Security/Infrastructure team for escalations  

---

## Acceptance Criteria

- Access issue identified and resolved.  
- Engineer can retrieve model artifacts, logs, or dashboards without errors.  
- Temporary workarounds documented if used.  
- Root cause fixed with least-privilege principle applied.  
