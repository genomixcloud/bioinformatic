# Kraken2 on AWS: cost per sample

Cost of the Kraken2 profiling run of 2026-11-13 (5 *P. aeruginosa* samples, 5 × r5.4xlarge, Kraken2 Standard database, about 103 GiB, on EFS One Zone `fs-05846c89e2da6b943` with Elastic throughput, the same file system as the Bakta database). Run times, data volumes and the technical findings come from [profiling_kraken2.md](profiling_kraken2.md).

Scope: EC2 compute and EFS (storage and reads) at On-Demand list prices. Not included: Savings Plans, Reserved Instances, Spot, and scaling to other instance types or thread counts.

## Summary

* **About $4.35 per sample, and EFS reads are 97 % of it.** Each sample reads the whole 103 GiB index from EFS. That costs $4.23 in read charges, against $0.12 for the instance time.
* **The storage class matters less than for Bakta.** Most of the read charge is the Elastic Throughput charge ($3.09 per sample), which applies in Standard and in IA alike. Moving the database to Standard would save only the IA part ($1.13).
* **The main lever is to read the database once instead of once per sample**, or not to read it from EFS at all: several samples per instance, or a copy on local disk. See [Biggest cost lever](#biggest-cost-lever).
* No decision has been taken. The lifecycle is set per file system, so a storage-class change for Kraken2 also affects Bakta, whose [decision](../bakta/cost_bakta.md#decision-keep-the-database-in-ia) was to stay in IA. **Counting both tools, the break-even for moving the file system to Standard is about 19 samples per month**, against 40–63 for Bakta alone (see [Both tools together](#both-tools-together)).

## Prices

The same prices as the [Bakta cost analysis](../bakta/cost_bakta.md#prices): AWS price list for EU (Ireland), EFS published 2026-11-04, EC2 published 2026-11-14. On-Demand, USD, before tax, Free Tier and discounts. AWS bills "GB" as GiB (2^30 bytes). CloudWatch reports bytes, so the byte counts are converted.

| Item | Price |
|---|---|
| r5.4xlarge On-Demand, Linux | $1.128 per hour |
| r5d.4xlarge On-Demand, Linux (with NVMe) | $1.280 per hour |
| EFS One Zone Standard storage | $0.176 per GB-month |
| EFS One Zone Infrequent Access storage | $0.0133 per GB-month |
| EFS IA reads | $0.011 per GB read from IA |
| EFS Elastic Throughput reads | $0.03 per GB read, in any storage class |
| EFS access from another Availability Zone | $0.01 per GB, only if the instance is not in the file system's AZ |

Not from that price list, and to be confirmed before relying on them: CloudWatch Logs ingestion, about $0.57 per GB, and S3 Standard storage, about $0.023 per GB-month.

## Cost per sample in this run

| Item | How it is worked out | Per sample (median) | Batch of 5 |
|---|---|---|---|
| Compute (EC2) | $1.128/h × run time (Batch `startedAt` → `stoppedAt`), one job per instance. The job requests 16/16 vCPU and 115,000 MiB of the 128 GiB, so the share is 100 % | $0.12 (0.08–0.15) | $0.58 |
| EFS Elastic Throughput reads | 515.8 GiB read (`TotalIOBytes`) × $0.03 | $3.09 | $15.47 |
| EFS IA reads | 515.8 GiB read from IA (`DataReadIOBytes`) × $0.011 | $1.13 | $5.67 |
| S3 | 0.35–0.53 GB of trimmed reads in, a 75–79 KiB report out, a few requests per sample | < $0.01 | < $0.05 |
| **Total** | | **≈ $4.35** | **≈ $21.73** |

On top of that, the Kraken2 index takes about 103 GiB of the file system's IA storage: **about $1.37 per month** (103.2 GiB × $0.0133), whatever the number of samples.

* **The cost per sample doesn't depend on the sample.** Every job reads the same 103 GiB, so the EFS charge is the same for a small or a large read set. Only the compute part varies, with the run time (4:26–8:10).
* **Not included above: CloudWatch Logs.** The Kraken2 command has no `--output`, so every read pair is printed to stdout and goes to CloudWatch Logs ([profiling](profiling_kraken2.md#wrapper-issues-reported-not-fixed)). **Measured:** 535.8 MB (0.50 GiB) and 1.85 million events reached the log group for the 5 jobs, so about **$0.28 per batch, or $0.06 per sample**, in ingestion, plus storage while the logs are kept. Probably not all the lines arrived: with every read pair logged it would be at least 0.27 GiB and **at least $0.15 per sample**.
* Compute here is the container run time only. The billed instance time also includes boot, image pull and the wait before Batch terminates the instance. **TBD:** the instance-hours actually billed (Cost Explorer or the Cost and Usage Report).
* The EFS charges are worked out from the CloudWatch byte counts. **TBD:** check them in Cost Explorer for 2026-11-13 (usage types `EU-ETDataAccess-Bytes`, `EU-IADataAccess-Bytes` and `EU-IATimedStorage-Z-ByteHrs`). The Bakta run on the same day used the same file system, so separate the two by hour.
* If the Batch instances run in a different AZ from the file system, each sample adds about $1.03 (103.2 GiB × $0.01). **TBD:** the subnets.

## What keeping the database in Standard costs

The lifecycle works as described in the [Bakta cost analysis](../bakta/cost_bakta.md#what-keeping-the-database-in-standard-costs). Two things are different for Kraken2:

* **Kraken2 reads every byte of its index on every run**, so with "Transition into Standard: On first access", the whole 103 GiB would move to Standard after the first run.
* **The setting applies to the whole file system**, so the files Bakta reads would move too. To decide for Kraken2 alone, its database needs its own file system.

For the Kraken2 index alone (103.2 GiB): extra storage = 103.2 GiB × ($0.176 − $0.0133) = **+$16.79 per month** ($18.16 instead of $1.37).

The saving per sample is the IA read ($1.13) plus the shorter run time ($0.019 per minute of r5.4xlarge). The run-time saving is **not measured**. With one sequential reader, the read rate is probably set by the read-ahead window ÷ latency ([profiling](profiling_kraken2.md#what-this-shows)), so Standard's lower latency could shorten the load. Not measured:

| Run-time saving per sample | Saving per sample | Break-even |
|---|---|---|
| 0 min (EFS charges only) | $1.13 | 15 samples per month |
| 2 min | $1.17 | 14 samples per month |
| 4 min | $1.21 | 14 samples per month |

Even above the break-even, Standard leaves $3.09 per sample of Elastic Throughput read charges. The options below cut more.

### Both tools together

The lifecycle is set per file system, and every pipeline sample runs both Bakta and Kraken2 on it. The [Bakta break-even](../bakta/cost_bakta.md#what-keeping-the-database-in-standard-costs) (40–63 samples per month) charged the whole 189.6 GiB to Standard but counted only Bakta's savings. Counting both:

| | Value |
|---|---|
| Extra storage, whole file system in Standard | 189.6 GiB × $0.1627 = **+$30.85 per month** |
| Saving per sample (EFS charges only, 0 min faster) | $0.49 (Bakta IA reads) + $1.13 (Kraken2 IA reads) = **$1.62** |
| **Combined break-even** | **about 19 samples per month** |

That is well below Bakta's 40–63. **The [Bakta decision](../bakta/cost_bakta.md#decision-keep-the-database-in-ia) to stay in IA should be reviewed with both tools counted.** Any run-time saving lowers the break-even further.

## Biggest cost lever

The **EFS read charges ($4.23 per sample)** come from reading the whole index for every sample. Three ways to cut them, all **not measured yet**:

| Option | What changes | Effect on cost per sample | What it costs |
|---|---|---|---|
| **Several samples per instance, one EFS read** (2–3 samples one after another inside one job on an r5.8xlarge, without `--memory-mapping`, which is slower in our setup) | The page cache keeps the index between runs, so it is read from EFS once per instance instead of once per sample | Saves up to **$4.23 for every extra sample** on the same instance, plus most of the load time | r5.8xlarge (256 GiB) instead of r5.4xlarge, with a job memory request of ≈215 GiB: the container's memory limit counts the page cache, and the cache and the process each need ~103 GiB. Separate jobs share the cache only through a shared (host) NFS mount. The r5.8xlarge price is twice the r5.4xlarge (**to confirm** in the price list) |
| **Copy in S3, loaded to local NVMe** (e.g. r5d.4xlarge) | No EFS reads. Reads from S3 in the same region have no per-GB charge **if S3 is reached through a gateway endpoint**. Through a NAT gateway, about $0.048 per GB, ≈$5 per copy (to confirm) | Saves about **$4.2 per sample** | r5d.4xlarge costs $0.152/h more. About $2.4 per month to keep 103 GiB in S3 Standard. The copy time per instance needs to be measured |
| **Smaller database** (Standard-16, 14.9 GiB) | 7 times fewer bytes read per sample | Reads fall to about **$0.61 per sample** | Lower sensitivity, a different release, and results no longer comparable with earlier runs or partner laboratories. Needs validation against Standard on real samples. It also fits a much smaller instance |

For comparison, the same lever for Bakta is worth up to $1.83 per extra sample ([cost_bakta.md](../bakta/cost_bakta.md#biggest-cost-lever)). With both tools on the same file system, a batch of 5 samples spent about $21.7 (Kraken2) + $12.3 (Bakta) ≈ **$34**, and about $30 of it was EFS reads.

## Data still needed

1. **Instance-hours actually billed** for the 5 instances.
2. **EFS charges in Cost Explorer** for 2026-11-13, split by hour from the Bakta run: `EU-ETDataAccess-Bytes`, `EU-IADataAccess-Bytes`, `EU-IATimedStorage-Z-ByteHrs`.
3. ~~CloudWatch Logs volume~~: measured (535.8 MB for 5 jobs). Still needed: the current CloudWatch Logs price.
4. **Batch subnets vs the EFS AZ:** whether cross-AZ charges apply.
5. **Run time with the database in Standard, on local disk, and from the page cache (second sample on r5.8xlarge)**, to replace the estimates above.
6. **Time and EFS bytes per sample with 2–3 samples per instance.**
7. **S3 path:** gateway endpoint or NAT gateway (decides whether the S3 → NVMe option has a per-GB charge).
