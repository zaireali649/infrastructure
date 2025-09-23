# 5. ML Infrastructure Scaling Runbook – Example

**Scenario:**  
The deployed Iris classifier (`iris_classifier_v3`) is receiving more inference requests than usual, causing high latency and occasional timeouts.

---

**Objective:**  
Scale ML infrastructure to meet demand for inference or training workloads while maintaining performance and availability.

---

## Steps (Example)

1. **Identify scaling trigger**  
   - Review monitoring metrics:  
     - Average latency > 400ms.  
     - CPU utilization > 80% for >10 minutes.  
     - Memory usage approaching container limits.  

2. **Determine scaling approach**  
   - **Horizontal scaling:** add more replicas of the model service.  
   - **Vertical scaling:** increase CPU/GPU/memory resources for existing nodes.  
   - Example: increase from 2 to 4 containers serving the Iris classifier.  

3. **Apply scaling changes**  
   - Update autoscaling configuration (Kubernetes HPA, ECS service, etc.).  
   - Apply resource changes via infrastructure-as-code or approved manual method.  

4. **Validate system performance**  
   - Run smoke test using known Iris input:  
     - `[6.3, 3.3, 6.0, 2.5]` → expected `class ≈ virginica`.  
   - Confirm predictions return within latency threshold.  

5. **Monitor after scaling**  
   - Ensure latency and error rates drop back to acceptable levels.  
   - Confirm new nodes/containers register healthy in monitoring dashboards.  

6. **Plan resource cleanup**  
   - If scaling was temporary (e.g., traffic spike), define a rollback or scale-down policy.  
   - Ensure cost impact is tracked and reported.  

---

## Troubleshooting (Example Issues)

- **Scaling doesn’t reduce latency:** bottleneck may be in data preprocessing, not model inference.  
- **Autoscaler misconfigured:** thresholds too high or low → adjust scaling policy.  
- **GPU contention:** multiple models competing for limited GPUs → redistribute workloads.  

---

## Contact Points

- **Primary:** ML Engineering oncall  
- **Secondary:** Platform/DevOps Engineering for infrastructure support  

---

## Acceptance Criteria

- Latency and error rates return to within defined SLOs.  
- Autoscaling or resource adjustments documented and tested.  
- Cost implications of scaling reviewed.  
- System monitored for stability after scaling.  
