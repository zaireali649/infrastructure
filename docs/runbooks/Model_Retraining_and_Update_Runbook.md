# 2. Model Retraining and Update Runbook – Example

**Scenario:**  
The current production model (`iris_classifier_v2`) may be outdated. New Iris dataset samples have been collected and a retrained version (`iris_classifier_v3`) needs to be validated and promoted.

---

**Objective:**  
Retrain models with updated data, evaluate performance, and update the deployed version without regressions.

---

## Steps (Example)

1. **Validate new data**  
   - Confirm schema matches expected Iris features: `[sepal_length, sepal_width, petal_length, petal_width]`.  
   - Check for missing values, duplicates, or corrupted rows.  

2. **Retrain the model**  
   - Run the training pipeline using scikit-learn:  
     - Example: `LogisticRegression` trained on the updated Iris dataset.  
   - Save artifact as `iris_classifier_v3.pkl`.  

3. **Evaluate model performance**  
   - Compare `v3` vs. `v2` on a hold-out test set.  
   - Ensure accuracy ≥ baseline (e.g., 95%).  
   - Check precision/recall for each class (setosa, versicolor, virginica).  

4. **Version control**  
   - Log training parameters, dataset version, and metrics in model registry.  
   - Assign version tag (`v3.0.0`).  

5. **Deploy retrained model**  
   - Follow steps from **Model Deployment Runbook**.  
   - Run inference smoke tests using known inputs:  
     - Input: `[6.7, 3.1, 4.4, 1.4]`  
     - Expected: `class ≈ versicolor`.  

6. **Monitor post-update performance**  
   - Ensure no significant drift compared to `v2`.  
   - Track metrics: latency, accuracy, prediction distribution.  

---

## Troubleshooting (Example Issues)

- **Training fails:** missing dependency or library mismatch → confirm environment reproducibility.  
- **Model underperforms:** accuracy < baseline → investigate data quality, features, or hyperparameters.  
- **Deployment mismatch:** inference results differ from training validation → confirm preprocessing consistency.  

---

## Contact Points

- **Primary:** ML Engineering oncall  
- **Secondary:** Data Engineering for dataset issues  

---

## Acceptance Criteria

- `iris_classifier_v3` trained and stored in registry with metadata.  
- Test accuracy ≥ previous production model.  
- Retraining logs and artifacts archived for reproducibility.  
- Deployment completed successfully via Model Deployment Runbook.  
- Post-update monitoring confirms stable performance.  
