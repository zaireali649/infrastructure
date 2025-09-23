# 4. Data Pipeline Failure Runbook – Example

**Scenario:**  
The training or inference data pipeline for the Iris classifier fails, preventing new data from being ingested or processed.

---

**Objective:**  
Resolve failures in data pipelines that feed training or inference models to restore normal operation.

---

## Steps (Example)

1. **Identify the failure**  
   - Review monitoring alerts and logs.  
   - Example: scheduled job to load new Iris samples into the feature store failed.  

2. **Check upstream data source**  
   - Confirm source dataset is available.  
   - Example: CSV file with Iris samples missing for the current date.  

3. **Validate schema and transformations**  
   - Ensure features `[sepal_length, sepal_width, petal_length, petal_width]` are present.  
   - Check transformations (e.g., scaling) didn’t introduce NaNs or corrupted values.  

4. **Re-run or repair the pipeline**  
   - Restart job with corrected configuration.  
   - If issue was missing file, trigger backfill with last known good dataset.  

5. **Validate pipeline output**  
   - Confirm feature store or database contains the expected records.  
   - Run a sample query: ensure ~150 Iris rows are loaded correctly.  

6. **Monitor downstream effects**  
   - Verify training jobs or inference services are consuming valid data again.  
   - Check that models are not producing errors due to missing inputs.  

---

## Troubleshooting (Example Issues)

- **Missing data file:** upstream system failed → escalate to Data Engineering.  
- **Schema mismatch:** new field added or removed → update preprocessing code.  
- **Transformation error:** division by zero or invalid operation → patch transformation logic.  

---

## Contact Points

- **Primary:** Data Engineering oncall  
- **Secondary:** ML Engineering for downstream impact  

---

## Acceptance Criteria

- Pipeline is restored and running successfully.  
- Data integrity validated (schema, ranges, row counts).  
- Downstream jobs (training or inference) consuming fresh data without errors.  
- Root cause documented and communicated.  
