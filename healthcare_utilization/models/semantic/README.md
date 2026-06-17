# Semantic Layer

This folder defines the MetricFlow semantic layer on top of the marts.

## Semantic Models
- `sm_specialty_cost_benchmarks` — specialty-level cost and volume measures
- `sm_geographic_variation` — state-year level spending and utilization measures

## Metrics (8 governed definitions)
- `total_medicare_spend` — total Medicare payment dollars
- `avg_payment_per_service` — volume-weighted average payment per service
- `total_services_rendered` — total services across all specialties
- `provider_count` — total providers represented
- `avg_patient_acuity` — average patient risk score
- `avg_payment_per_capita` — average Medicare payment per beneficiary by state-year
- `avg_readmission_rate` — average hospital readmission rate by state
- `high_cost_specialty_concentration` — ratio metric: spend per service, used to identify high-cost-per-unit specialties

## Example queries
```bash
mf query --metrics total_medicare_spend --group-by specialty --order -total_medicare_spend --limit 10
mf query --metrics high_cost_specialty_concentration --group-by specialty --order -high_cost_specialty_concentration --limit 10
mf query --metrics avg_payment_per_capita --group-by state_code --order -avg_payment_per_capita --limit 10
```

Any BI tool or AI assistant connecting to this semantic layer gets the same metric definitions — no risk of two dashboards disagreeing on what "total Medicare spend" means.
