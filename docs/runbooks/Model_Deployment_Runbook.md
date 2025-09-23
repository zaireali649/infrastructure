# 1. Model Deployment Runbook – Example

**Scenario:**  
A new machine learning model (`iris_classifier_v2`) trained on the Iris dataset has passed validation and needs to replace the current production model (`iris_classifier_v1`).

---

**Objective:**  
Deploy a new or updated ML model into production, validate functionality, and roll back if issues occur.

---

## Steps (Example)

1. **Verify model artifact integrity and version**  
   - Check that `iris_classifier_v2.pkl` in storage (e.g., S3, GCS, local registry) has the correct checksum.  
   - Confirm version tag (`v2.0.0`) is unique and properly recorded.

2. **Configure deployment environment**  
   - Update deployment service (e.g., container, serverless function).  
   - Ensure environment variables are set (e.g., `MODEL_VERSION=2`).  

3. **Load model and dependencies**  
   - Container loads the model artifact.  
   - Verify dependencies (e.g., scikit-learn 1.2.0) are consistent with training.  

4. **Perform smoke tests and inference checks**  
   - Run simple test cases using known Iris inputs:  
     - Input: `[5.1, 3.5, 1.4, 0.2]`  
     - Expected: `class = setosa`  
   - Validate outputs fall within expected ranges.  

5. **Gradual rollout strategy**  
   - Deploy `iris_classifier_v2` to a small percentage of traffic (canary).  
   - Monitor metrics: latency < 200ms, prediction distribution aligned with baseline.  

6. **Monitor post-deployment health**  
   - Check error rates, latency, and prediction distributions in monitoring system.  
   - Compare with previous version during overlap.  

7. **Rollback plan**  
   - If latency, error rate, or predictions deviate beyond threshold, roll back:  
     - Revert to `iris_classifier_v1`.  
     - Confirm rollback success in logs and monitoring.  

---

## Troubleshooting (Example Issues)

- **Deployment error:** container fails on startup → check image build logs.  
- **Dependency conflict:** model requires scikit-learn 1.2.0 but container has 1.3.0 → fix requirements.  
- **Resource limits:** inference memory exceeds container size → increase resources or optimize model.  

---

## Contact Points

- **Primary:** ML Engineering oncall  
- **Secondary:** DevOps / Platform Engineering  

---

## Acceptance Criteria

- `iris_classifier_v2` is live in production, serving >95% of traffic.  
- Smoke tests and canary rollout validate successfully.  
- Monitoring shows no anomalies compared to `iris_classifier_v1`.  
- Rollback plan is validated and documented.  
