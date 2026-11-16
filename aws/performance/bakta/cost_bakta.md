# Bakta on AWS: cost per sample

Cost of the Bakta profiling run of 2026-11-13 (5 *P. aeruginosa* genomes, 5 × r5.4xlarge On-Demand, `--threads 16`, full database v6.0 on EFS One Zone `fs-05846c89e2da6b943` with Elastic throughput). Run times, data volumes and the technical findings come from [profiling_bakta.md](profiling_bakta.md).

Scope: EC2 compute and EFS (storage and reads) at On-Demand list prices. Not included: Savings Plans, Reserved Instances, Spot, and scaling to other instance types or thread counts.

## Decision: keep the database in IA

**Priority:** lower cost over speed. A run about 10 minutes slower per sample is acceptable if it is cheaper.

**Decision:** keep the database in EFS Infrequent Access, as it is now ("Transition into Standard: None"). No change to the file system.

| | IA (current) | Standard |
|---|---|---|
| Storage | ~$2.52 per month | up to ~$33.37 per month (if the whole 189.6 GiB moves) |
| IA read charge | ~$0.49 per sample | none |
| Bakta run time | 33:19 median (measured) | estimated 10–15 min shorter (**not measured**) |
| Cheaper when | fewer than ~40–63 samples per month | more than ~40–63 samples per month |

* **IA is cheaper below roughly 40–63 samples a month.** The exact break-even depends on how much faster Standard really is (see [break-even table](#what-keeping-the-database-in-standard-costs)).
* **The price of IA is time.** The database lookups take about 19 of the 33 minutes, and IA's slower reads are the likely main cause ([profiling_bakta.md](profiling_bakta.md)).
* **Batch effect:** Roary waits for the slowest Bakta job, so the slower runs delay the whole batch, not just one sample.
* **The threshold may be lower than 40–63.** The full database is about 64 GB, but the file system holds 203.6 GB. If only the ~60 GiB that Bakta reads moved to Standard, the extra storage would be about $9.8 per month and the break-even about **13–20 samples per month**. The Standard speed-up may also be larger than 10–15 min: the UPS lookups alone take ~16 min at ~35 ms per read, against ~1 ms on Standard. Both points are unmeasured. They don't change the decision, but they lower the volume at which to review it.
* **Review this decision** if volume goes above ~15–20 samples a month, or if the time to finish a batch starts to matter more than cost. Measuring a run with the database in Standard, and `du -sh /mnt/efs/bakta_db/*`, would replace the estimates above.

## Prices

Prices from the AWS price list for EU (Ireland): EFS published 2026-11-04, EC2 published 2026-11-14. On-Demand, USD, before tax, Free Tier and discounts. AWS bills "GB" as GiB (2^30 bytes). CloudWatch reports bytes, so the byte counts are converted.

| Item | Price |
|---|---|
| r5.4xlarge On-Demand, Linux | $1.128 per hour |
| EFS One Zone Standard storage | $0.176 per GB-month |
| EFS One Zone Infrequent Access storage | $0.0133 per GB-month |
| EFS IA reads | $0.011 per GB read from IA |
| EFS transition into IA | $0.011 per GB moved |
| EFS Elastic Throughput reads | $0.03 per GB read, in any storage class |
| EFS Elastic Throughput writes | $0.07 per GB written |
| EFS access from another Availability Zone | $0.01 per GB, only if the instance is not in the file system's AZ |

## Cost per sample in this run

| Item | How it is worked out | Per sample (median) | Batch of 5 |
|---|---|---|---|
| Compute (EC2) | $1.128/h × container run time × the job's share of the instance. The job requests 16/16 vCPU and 120/128 GiB, so the share is 100 % | $0.63 (0.59–0.67) | $3.14 |
| EFS Elastic Throughput reads | 223.6 GiB read (`TotalIOBytes`) × $0.03 | $1.34 | $6.71 |
| EFS IA reads | 223.4 GiB read from IA (`DataReadIOBytes`) × $0.011 | $0.49 | $2.46 |
| S3 | ~6 MiB in, ~102 MiB out and about 20 requests per sample | < $0.01 | < $0.05 |
| **Total** | | **≈ $2.46** | **≈ $12.31** |

On top of that, EFS storage is a fixed **$2.52 per month** (189.6 GiB in IA × $0.0133), whatever the number of samples.

* **EFS reads cost more than the compute: $1.83 of $2.46 per sample (74 %).** Almost all of it is the Diamond stage, which reads ~46.5 GB per job. The Elastic Throughput read charge applies in Standard and in IA alike. Only a local copy of the database removes it.
* Compute here is the container run time only. The billed instance time also includes boot, image pull and the wait before Batch terminates the instance. **TBD:** instance launch and termination times, and the instance-hours actually billed (Cost Explorer or the Cost and Usage Report).
* The EFS charges are worked out from the CloudWatch byte counts. **TBD:** check them in Cost Explorer for 2026-11-13 (usage types `EU-ETDataAccess-Bytes` and `EU-IADataAccess-Bytes`).
* If the Batch instances run in a different AZ from the file system, each sample adds about $0.44 (47.5 GB × $0.01). **TBD:** the subnets.
* NAT gateway: **TBD** whether S3 traffic goes through a gateway endpoint. With ~110 MB per sample, the effect is small either way.

## What keeping the database in Standard costs

How the lifecycle works with "Transition into Standard: On first access" and "Transition into IA: 14 days":

* **The first read of a file in IA moves it to Standard.** That read is still billed as an IA read, and that run is still slow. The speed-up starts with the next run.
* **Every read of a file in Standard resets its 14-day timer.** If samples run at least once every 14 days, the files Bakta reads stay in Standard permanently, so **you pay Standard storage all the time** (13 × the IA price) and stop paying IA reads.
* **Only the files that are read move.** Files Bakta never reads stay in IA. How much of the 203.6 GB Bakta reads is **TBD** (`du` of the database). It is at least the Diamond databases plus the SQLite database, and at most everything.
* If 14 days pass with no run, the files go back to IA. That costs $0.011 per GB (≈ $2.09 for 189.6 GiB), and the next run is slow again.
* Setting "Transition into IA" to **None** for this file system gives the same cost as running at least every 14 days, without the risk of falling back to IA.

Extra storage cost of keeping files in Standard = GiB in Standard × ($0.176 − $0.0133) = **$0.163 per GiB per month**. For all 189.6 GiB that is **+$30.85 per month** ($33.37 instead of $2.52).

It pays for itself when the saving per sample covers that. The saving is the IA read ($0.49 per sample) plus the shorter instance time. The run-time saving is **not measured yet**, so the table shows several values:

| Run-time saving per sample | Saving per sample | Break-even, all 189.6 GiB in Standard |
|---|---|---|
| 0 min (EFS charges only) | $0.49 | 63 samples per month |
| 5 min | $0.59 | 53 samples per month |
| 10 min | $0.68 | 46 samples per month |
| 15 min | $0.77 | 40 samples per month |

Below the break-even, Standard costs more each month. Above it, Standard is cheaper overall. If only part of the database moves to Standard, the extra storage and the break-even drop in proportion. For example, with 100 GiB in Standard: +$16.27 per month, break-even 21–33 samples per month.

## Biggest cost lever

The **EFS Elastic Throughput read charge ($1.34 per sample)** is the largest item, and it doesn't change with the storage class. Two ways to cut it:

* **Several samples per instance (fits the decision to stay in IA).** Each job reads ~46.5 GB of protein database, and it stays in the instance's memory cache (the pseudogene-candidate search re-reads it with almost no EFS traffic). Running 2–3 samples on the same instance, one after another or together, could avoid most of that read for every extra sample: up to ~$1.83 per extra sample in EFS reads (Elastic plus IA), and less instance start-up. **Not measured yet.**
* **A database on local storage** removes the EFS reads entirely. Local storage has its own costs, which the local-disk test should measure. For example, r5d.4xlarge (with NVMe) costs $1.280/h instead of $1.128/h (+$0.08 per 33-minute job), and the database has to be copied onto each new instance.

## Data still needed

1. **Instance-hours actually billed** for the 5 instances (Cost Explorer or the Cost and Usage Report), plus instance launch and termination times. These give the boot, image pull and scale-down time that the container run time leaves out.
2. **EFS charges in Cost Explorer** for 2026-11-13: `EU-ETDataAccess-Bytes`, `EU-IADataAccess-Bytes` and `EU-IATimedStorage-Z-ByteHrs`, to check the amounts worked out from CloudWatch.
3. **Database file sizes** (`du -sh /mnt/efs/bakta_db/*`): how much would move to Standard.
4. **Batch subnets vs the EFS AZ:** whether cross-AZ charges apply.
5. **S3 path:** gateway endpoint or NAT gateway.
6. **Run time with the database in Standard** (and on local disk), to replace the assumed savings in the break-even table.
7. **Time and EFS bytes per sample with 2–3 samples per instance**, to measure the cost lever above.
8. **What the extra ~140 GB on the file system is**, beyond the ~64 GB database.

