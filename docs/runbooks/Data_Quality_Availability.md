# 6. Data Quality & Availability Runbook – Example

**Scenario:**  
The Iris classifier (`iris_classifier_v3`) receives input data with missing or corrupted features, or an expected data source is delayed.

---

**Objective:**  
Handle situations where upstream data is delayed, missing, corrupted, or otherwise unusable to minimize disruption to ML workflows.

---

## Steps (Example)

1. **Confirm the issue**  
   - Review logs/alerts showing data anomalies.  
   - Example: incoming records missing `petal_width`.  
   - Example: scheduled dataset update file not delivered.  

2. **Validate schema and ranges**  
   - Ensure required features `[sepal_length, sepal_width, petal_length, petal_width]` are present.  
   - Run sanity checks: no negative values, ranges align with expected Iris data (e.g., sepal length ~4–8 cm).  

3. **Assess model impact**  
   - Check whether missing/corrupted data affects inference or retraining jobs.  
   - Example: if `petal_width` is missing, the model may fail to generate predictions.  

4. **Apply workarounds**  
   - Use fallback or imputed values (e.g., median feature values) for inference until source is fixed.  
   - Trigger backfill from last known good dataset if delivery is delayed.  

5. **Escalate if needed**  
   - If data source is external, contact provider and open incident.  
   - If internal, escalate to Data Engineering for resolution.  

6. **Validate fix**  
   - Re-run data validation checks.  
   - Confirm model processes input correctly and retraining pipelines complete without errors.  

---

## Troubleshooting (Example Issues)

- **Missing features:** dataset missing `petal_width` → update pipeline to enforce schema validation.  
- **Out-of-range values:** negative measurements detected → reject or clean records.  
- **Corrupted file:** file fails parsing → request re-delivery or reload from backup.  

---

## Contact Points

- **Primary:** Data Engineering oncall  
- **Secondary:** ML Engineering for retraining/inference impact  

---

## Acceptance Criteria

- Root cause of data issue identified and documented.  
- Workaround or permanent fix applied.  
- Data validated against schema and value checks.  
- Model and pipelines confirmed functional after resolution.  
