# Cost log

Costs come from the Billing → Reports page, filtered by project and grouped by SKU. Billing data lags by up to about 24 hours.

| Date | Lab | Duration | Resources | Cost (USD) | Notes |
|---|---|---|---|---|---|
| 2026-10-04 | 01 | ~51 min cluster (19:51–20:42 UTC); ~20 min GPU node time over 3 nodes | zonal GKE, 1× e2-standard-2, Spot g2-standard-4 (L4) 0→1 | _pending billing_ | 1 Spot preemption; the first GPU node was pinned by system pods until the taint fix |
