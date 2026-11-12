# Metric definitions

| Metric | Definition | Grain |
|---|---|---|
| **North Star: policies bound** | Count of `policy_bound` events | Week |
| Weekly active accounts | Accounts with at least one `quote_request_submitted` in the week | Week |
| Quote submit rate | Quotes submitted / quote forms started | Week, segment |
| Carrier response rate | Carrier quotes returned / carriers requested | Week, line of business |
| Bind rate | Quotes bound / quotes with at least one carrier response | Week, segment |
| Account retention (week N) | % of a weekly cohort of accounts active in week N after their first quote | Cohort week |
| Client tracking loss | 1 - client `quote_submit_clicked` / server `quote_request_submitted` | Week |
