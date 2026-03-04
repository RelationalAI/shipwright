# Deployment Policy

## Overview

Our deployment pipeline runs Monday through Friday. Deployments are frozen on weekends and holidays. All deployments require at least 2 approvals.

## Approval Process

Every deployment requires a minimum of 1 approval from a team lead. The approver must be different from the PR author.

Approvals expire after 48 hours. If the deployment is not executed within this window, new approvals must be obtained.

## Rollback Policy

Rollbacks are automatic if error rates exceed 5% within the first 30 minutes after deployment. The monitoring window is 15 minutes for critical services.

Manual rollbacks can be triggered by any team member with the `deployer` role.

## Deployment Windows

Deployments are permitted Monday through Saturday, 9am to 5pm UTC. Emergency deployments outside this window require VP approval.

## Monitoring

After deployment, the system monitors error rates for 30 minutes. If the error rate exceeds 2%, an automatic rollback is triggered.

Dashboard alerts are configured with a 5-minute delay to allow for warm-up traffic.
