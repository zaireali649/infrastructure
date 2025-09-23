# 3. Model Monitoring and Alerting Runbook – Example

**Scenario:**  
An alert fires because the deployed model (`iris_classifier_v3`) shows a drop in accuracy or unexpected input distributions compared to baseline.

---

**Objective:**  
Investigate and resolve alerts related to model performance degradation, data drift, or inference issues.

---

## Steps (Example)

1. **Review alert details**  
   - Check monitoring dashboard for trigger:  
     - Accuracy below 90% on validation window.  
     - Latency > 500ms.  
     - Prediction distribution skewed (e.g., 90% of predictions suddenly classified as `virginica`).  

2. **Investigate input data**  
   - Pull recent inference samples.  
   - Validate features: `[sepal_length, sepal_width, petal_length, petal_width]` are within expected ranges.  
   - Example anomaly: `sepal_length` values < 0 detected → likely bad data ingestion.  

3. **Check model outputs**  
   - Compare predictions on golden test cases:  
     - Input: `[5.1, 3.5, 1.4, 0.2]` → expected `setosa`.  
     - If misclassified, model may be corrupted or improperly loaded.  

4. **Evaluate drift and degradation**  
   - Compare current input distribution vs. training distribution.  
   - If drift detected, document and consider retraining (see Retraining Runbook).  

5. **Decide action**  
   - **If data issue:** escalate to Data Engineering and patch dataset.  
   - **If model corruption:** roll back to previous version (`iris_classifier_v2`).  
   - **If drift/accuracy drop confirmed:** plan retraining cycle.  

6. **Communicate incident status**  
   - Post update in incident channel.  
   - Document root cause and actions taken.  

---

## Troubleshooting (Example Issues)

- **False alarm:** monitoring thresholds too strict → adjust thresholds or add alert dampening.  
- **Bad input data:** invalid ranges (negative sepal lengths) → validate ingestion pipeline.  
- **Performance regression:** retraining introduced weaker model → revert to stable version.  

---

## Contact Points

- **Primary:** ML Engineering oncall  
- **Secondary:** Data Engineering for source data anomalies  

---

## Acceptance Criteria

- Root cause (data, model, or infra) identified and documented.  
- Corrective action taken (rollback, retrain, or fix pipeline).  
- Alert closed with resolution details.  
- Monitoring thresholds reviewed and tuned if necessary.  
