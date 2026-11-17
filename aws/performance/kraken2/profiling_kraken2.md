# Kraken2 profiling on AWS

Status: **first run analysed.** Built from one test batch (5 samples, 5 EC2 instances, one job each) on 2026-11-13, 13:21–13:31 UTC. Sources: AWS Batch `describe-jobs`, CloudWatch EC2, EFS and Logs metrics, and from each job log the non per-read lines (S3 transfers, Kraken2's "Loading database information... done.", warnings) plus its last 200 events. Kraken2's final summary (classification time, read count) didn't reach CloudWatch, so the classification time is measured on one job (9.0 s) and estimated on the others from their last per-read event (9–14 s). Cost and scaling are out of scope here. The cost analysis is in [cost_kraken2.md](cost_kraken2.md). Values marked **TBD** need data that isn't in these sources. See [section 10](#10-open-questions-and-data-still-needed). The method follows the [Bakta profiling](../bakta/profiling_bakta.md), and the two runs used the same EFS file system. Reviewed by the `bioinformatic-python` agent on 2026-11-17; its corrections are included.

## Key findings

1. **Each job ran for 4:26–8:10 (median 6:34), and 92–95 % of that time was loading the database: 4:04–7:44 (median 6:12).** Every job read about **103 GiB from EFS**: the whole Kraken2 Standard index, read in 1 MiB sequential reads. The size is consistent with the Standard release of June 2026 (103.1 GiB). The CPU was at 4.5–7 % (about 1 vCPU of 16) during the load. Classifying the reads took 9.0 s on the one job with Kraken2's summary, and about 9–14 s on all jobs judging by their last per-read event. Everything after the load took 14.5–19.4 s, growing with the input size. The input download took about 3 s.
2. **How long a job took depended on its read speed, and in this run the later-starting jobs read faster.** The first job loaded at 239 MB/s on average and took 8:10. The last two started 4.5 minutes later and loaded at 381–454 MB/s, taking 4:26 and 5:11. Three jobs that started up to 2:06 apart **finished loading within 3.1 s of each other** (13:29:50.8–13:29:53.9), and two of them within 0.23 s. With 5 jobs and no repeats, this is a pattern, not a proven effect. The pattern is the same as in the Bakta run: data that another job has just read seems to be served faster. This is a hypothesis, not proven.
3. **The database is on the same EFS file system as the Bakta database (`fs-05846c89e2da6b943`), and the whole file system is in Infrequent Access (IA).** At 103 GiB, Kraken2 is more than half of the file system's 189.6 GiB. That probably explains most of the "extra ~140 GB" that the Bakta profiling couldn't account for.
4. **The 5 loads together peaked at 1.65 GB/s, which is 51 % of the file system's throughput limit.** About 7–10 Kraken2 jobs loading at the same time would reach the limit, or fewer if Bakta jobs are running Diamond on the same file system at the same time.
5. **Cost: about $4.35 per sample, and EFS reads are 97 % of it** ($4.23 for reads against $0.12 for compute). See [cost_kraken2.md](cost_kraken2.md).
6. **The memory headroom is small.** The job requests 115,000 MiB (112.3 GiB) and loads a 103 GiB database into it, which leaves about 9 GiB. With the current Standard release (Oct 2026, 109.4 GiB) it would leave under 3 GiB. The Bakta job already requests 122,880 MiB on the same instance type, so the request can go up by about 7.7 GiB.
7. **The job wrapper has three issues**, reported here and not fixed: the Kraken2 command has no `--output`, so Kraken2 prints one line per read pair to stdout, which goes to CloudWatch Logs (536 MB and 1.85 million events for the 5 jobs, and probably not all of it arrived); there is an unterminated here-document, the same as in the Bakta wrapper; and two different jobs had the same name. See [section 5](#5-variability-and-failures).

## Contents

1. [Scope and test setup](#1-scope-and-test-setup)
2. [Time breakdown per job](#2-time-breakdown-per-job)
3. [Resource use](#3-resource-use)
4. [EFS database access](#4-efs-database-access)
5. [Variability and failures](#5-variability-and-failures)
6. [Bottlenecks and recommendations](#6-bottlenecks-and-recommendations)
7. [Pipeline view](#7-pipeline-view)
8. [Extra technical checks](#8-extra-technical-checks)
9. [Charts](#9-charts)
10. [Open questions and data still needed](#10-open-questions-and-data-still-needed)

---

## 1. Scope and test setup

### Goal

Find where Kraken2 spends its time on AWS Batch when the Standard database is read from EFS. Collect the evidence needed to decide where the database should live and how big the job should be (vCPU, memory, `--threads`).

### In and out of scope

| In scope | Out of scope |
|---|---|
| Kraken2 only | fastp, SPAdes, Bakta, Roary |
| Technical metrics: run time, CPU, network, EBS, EFS | Scaling (thread count, read count, instance families) |
| One setting, one job per instance | Cost: see [cost_kraken2.md](cost_kraken2.md) |

### Software

| Item | Version |
|---|---|
| Kraken2 | **TBD.** The image in this repo builds 2.1.6 ([`tools/kraken2`](../../../tools/kraken2)). The production image isn't confirmed |
| Database | **Kraken2 Standard, release TBD.** About 103.2 GiB was read per job, which is consistent with the June 2026 release (103.1 GiB, see [database setup](../../database-setup/kraken2)) and rules out the Oct 2026 release (109.4 GiB). Caveats: 103.2 GiB is the average of file-system-wide counters over 5 jobs (with an unexplained 6th client at 13:28), the published index sizes are rounded to 0.1 GiB, and releases before June 2026 aren't in the sources. Confirm with `ls -l hash.k2d` or the folder name |
| Docker image | Production wrapper `/src/kraken2.sh` (at least 111 lines). It is not the script in [`tools/kraken2/src`](../../../tools/kraken2/src/kraken2.sh). Tag and size **TBD** |

### Infrastructure

| Item | Value |
|---|---|
| Region | eu-west-1 |
| Compute | AWS Batch on EC2, compute environment `r5_4x_large_biotoolkraken2`: 5 instances, one job per instance |
| Instance type | r5.4xlarge (16 vCPU, 128 GiB RAM, EBS only, no instance store), from the compute environment name |
| vCPU / memory requested per job | 16 vCPU / 115,000 MiB (112.3 GiB), from the job definition. The job takes the whole instance |
| Kraken2 options | `--threads 16` (`$PARAMETERS`), `--paired`, `--db`, `--report`. **No `--output`** and **no `--memory-mapping`**. Full command below |
| `--memory-mapping` | **Not used** (confirmed), on purpose: in our setup it is slower than loading the index into memory (earlier tests with Kraken2 2.1.3: [memory-mapping option](https://github.com/ldipotetjob/kraken2/blob/kraken2aws_profilingfromv2.1.3/docs/Kraken2paramsonAWS/memory-mapping.md)). This fits what EFS shows: each job read the whole index once, sequentially, which is how Kraken2 loads a database into memory |
| Purchase option | On-Demand (assumed, as in the Bakta run; **TBD**) |
| CloudWatch EC2 monitoring | Basic (5-minute points). Status checks are every minute |

### Kraken2 command

The same on every job, from the production `/src/kraken2.sh`, with `$PARAMETERS` = `--threads 16`:

```
kraken2 --paired $fastq_forward $fastq_reverse --db $KRAKENDB $PARAMETERS \
        --report $DATA_OUT/taxonomic_identification/$pattern.kraken-report.txt
```

The command has no `--output`, so Kraken2 writes its per-read output to stdout (section 5). It has no `--memory-mapping`, so Kraken2 loads the whole index into memory, and no `--confidence`, so the default threshold of 0 applies.

### Database location: EFS

The same file system as the Bakta database. Its settings are described in the [Bakta profiling](../bakta/profiling_bakta.md#database-location-efs).

| Setting | Value |
|---|---|
| File system | `fs-05846c89e2da6b943`. Kraken2 mount path **TBD** |
| Availability | One Zone |
| Throughput mode | Elastic (`PermittedThroughput` = 1 GiB/s of metered throughput; reads count at one third, so about 3 GiB/s of reads) |
| Lifecycle | Into IA after 14 days; no "Transition into Standard" |
| Data stored during the run | 203.6 GB (189.6 GiB), of which **203.6 GB in IA** and 0.58 MB in Standard |

### Samples and instances

These are the same 5 *P. aeruginosa* isolates as in the Bakta run. Kraken2 classifies their reads (2 × up to 301 bp, MiSeq), not the assemblies.

| Sample | Instance | Batch job | Job start (Batch) | Raw reads R1 + R2 (gzip) | Trimmed reads downloaded (fastp output, R1 + R2) |
|---|---|---|---|---|---|
| Sample_BB_S7 | `i-05dcd73d4cab124f5` | `6759685e` (`aws-batch-biotoolkraken2`) | 13:21:17.971 | 305 + 372 MB | 500.9 MiB |
| Sample_A4_S8 | `i-03af2f62857655d64` | `e56751bd` (`aws-batch-biotoolkraken2-1`) | 13:23:38.241 | 271 + 326 MB | 357.1 MiB |
| Sample_A3_S11 | `i-0e40ae0063bb8ed3c` | `e752f654` (`aws-batch-biotoolkraken2-1`) | 13:23:38.316 | 263 + 318 MB | 437.4 MiB |
| Sample_A2_S1 | `i-0a9b9340c95a31c35` | `71d59783` (`aws-batch-biotoolkraken2-3`) | 13:25:44.289 | 277 + 355 MB | 372.7 MiB |
| Sample_A1_S8 | `i-0b9d8421ed2492e8e` | `1e0b9d49` (`aws-batch-biotoolkraken2-4`) | 13:25:50.579 | 236 + 300 MB | 330.1 MiB |

Jobs were matched to instances through their container instance (`describe-jobs`, then the CloudTrail `RegisterContainerInstance` events), and to samples through the output paths in each log.

The raw read sizes are from the sequencing files. Kraken2 reads the fastp output, which the wrapper downloads from the sample's `fastp/` folder in S3 (last column, from the wrapper's S3 log). Sample_A1_S8 had 423 unclassified sequences (0.04 %), which puts it at roughly 0.9–1.2 million read pairs. The read counts of the other samples are **TBD**.

### Test design

| Item | Value |
|---|---|
| Repeats | None: each sample ran once |
| Cold or warm | All cold on the instance: a new instance per job, so the database came from EFS (IA) |
| Concurrency | 5 jobs in three waves: 1 at 13:21, 2 at 13:23:38, 2 at 13:25:44–50, all reading the same file |
| Jobs per instance | 1 |

### How we measured

| Source | What it gives | Resolution |
|---|---|---|
| Batch `describe-jobs` | `startedAt`, `stoppedAt`, container instance | Milliseconds |
| CloudWatch Logs (job stdout and stderr), filtered to the non per-read lines | S3 download and upload, "Loading database information... done.", warnings | Event timestamps (ms) |
| CloudWatch Logs, last 200 events of each job | End of Kraken2's per-read output, the wrapper's elapsed time | Event timestamps |
| CloudWatch `AWS/Logs`, log group `/batch/biotools-kraken2` | IncomingBytes, IncomingLogEvents | 1 min |
| CloudWatch `AWS/EC2`, per instance | CPUUtilization (avg, max), NetworkIn/Out, EBS read/write, status checks | 5 min (basic monitoring); status checks every 1 min |
| CloudWatch `AWS/EFS` | Data and metadata read/write bytes and ops, TotalIOBytes, MeteredIOBytes, PermittedThroughput, PercentIOLimit, ClientConnections, StorageBytes by storage class | 1 min |

### Limitations

* **Kraken2's final summary is missing.** "Loading database information... done." is in every log, so the load time is measured. But the summary printed after the classification ("N sequences processed in X s", classified and unclassified counts) reached CloudWatch only for Sample_A1_S8, and only its last line ("423 sequences unclassified"). Probably not all of the output reached CloudWatch (section 5). So the classification time is measured on one job; on the others it is estimated from the last per-read event, which Kraken2 writes as it finishes classifying. The read counts aren't measured.
* **5-minute EC2 points, and they look shifted against EFS.** The NetworkIn totals of the 5 instances match the EFS read total to within 1 % (559 GB against 554 GB). But the EC2 points before 13:25 hold 29 GB less than EFS counts for 13:21–13:24, and the 13:30 points 40 GB more than EFS counts from 13:30. Use EFS for timing and EC2 for per-instance totals.
* **No memory metric.** That needs the CloudWatch agent or Container Insights.
* **No Batch `createdAt`.** Queue wait and instance start-up can't be measured.
* **Shared EFS.** The jobs ran together and affected each other (section 5).
* One run, one setting, and the database was in IA the whole time.

---

## 2. Time breakdown per job

### From job submission to end

| Phase | Source | Value |
|---|---|---|
| Queue wait + instance start-up (`createdAt` → `startedAt`) | Batch `describe-jobs` | **TBD** |
| Image pull and extraction | EC2 EBS | **TBD.** The first 5-minute EBS point of each instance shows 2.1–2.35 GB written and ~0.78 GB read, consistent with pulling the image (section 3) |
| Input download from S3 (330–501 MiB, 2 files) | Wrapper log | **2.7–3.2 s** from Batch start to the end of the download, including the wrapper's start-up. The AWS CLI reports 289–318 MiB/s for the transfer itself |
| **Database load (~103 GiB from EFS)** | Download end → "Loading database information... done." | **4:04–7:44** (median 6:12), **92–95 % of the run** |
| Classification (~1 million read pairs) | "done." → "unclassified" line, or → last per-read event | **9.0 s** measured (Sample_A1_S8, the only job with the line). From the last per-read event: 9.0–13.7 s on all 5 jobs |
| Kraken2 summary → report uploaded (75–79 KiB) | Wrapper log | 5.5 s (Sample_A1_S8). From the end of the load to the upload: 14.5–19.4 s on all jobs |
| Wrapper end → Batch stop | Wrapper log, Batch | 3.2–3.4 s |
| **Container run time (`startedAt` → `stoppedAt`)** | Batch | **4:26–8:10** (median 6:34) |

Per job:

| Sample | Batch start | Download done | Load done | Report uploaded | Batch stop | Download | **Load** | After load | Run time (Batch) | Load share | Load rate |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Sample_BB_S7 | 13:21:17.971 | 13:21:21.144 | 13:29:05.294 | 13:29:24.648 | 13:29:28.183 | 3.2 s | **7:44.1** | 19.4 s | **8:10.2** | 94.7 % | 239 MB/s |
| Sample_A4_S8 | 13:23:38.241 | 13:23:41.035 | 13:29:53.655 | 13:30:08.602 | 13:30:11.984 | 2.8 s | **6:12.6** | 14.9 s | 6:33.7 | 94.6 % | 297 MB/s |
| Sample_A3_S11 | 13:23:38.316 | 13:23:41.500 | 13:29:53.887 | 13:30:11.558 | 13:30:14.976 | 3.2 s | **6:12.4** | 17.7 s | 6:36.7 | 93.9 % | 297 MB/s |
| Sample_A2_S1 | 13:25:44.289 | 13:25:47.037 | 13:29:50.809 | 13:30:06.451 | 13:30:09.834 | 2.7 s | **4:03.8** | 15.6 s | **4:25.5** | 91.8 % | 454 MB/s |
| Sample_A1_S8 | 13:25:50.579 | 13:25:53.303 | 13:30:44.141 | 13:30:58.655 | 13:31:02.006 | 2.7 s | **4:50.8** | 14.5 s | 5:11.4 | 93.4 % | 381 MB/s |

* **Load** = from the end of the input download to Kraken2's "Loading database information... done.", so it includes Kraken2's start-up (well under a second). **Load rate** = 110.8 GB (the EFS read per job) ÷ load time.
* **After load** = from "done." to the report upload: classification, the summary, the report upload, and writing ~1 million per-read lines to stdout. On Sample_A1_S8 the classification itself took 9.0 s. The last per-read event of each job, which Kraken2 writes as it finishes, comes 9.0 s (A1), 9.5 s (A4), 10.1 s (A2), 12.0 s (A3) and 13.7 s (BB) after "done.", then 5.5–5.6 s to the upload on every job. The after-load time grows with the input size: 14.5 s at 330 MiB, 19.4 s at 501 MiB.
* The wrapper's printed time ("N minutes and N seconds elapsed") is about 3 s shorter than Batch's, and its "Generated at" time is the job start.
* **The load median is 6:12 and the rest of the job takes about 20 s.** Making the classification faster wouldn't change the run time: only the load matters.

---

## 3. Resource use

### CPU

CPUUtilization (%) of the instance, 5-minute average (and maximum). 100 % = 16 vCPU, so 6.25 % = 1 vCPU. The EC2 points look shifted by a few minutes against EFS (section 1), so the stages are only approximate.

| Point (UTC) | Sample_BB (i-05dc…) | Sample_A4 (i-03af…) | Sample_A3 (i-0e40…) | Sample_A2 (i-0a9b…) | Sample_A1 (i-0b9d…) |
|---|---|---|---|---|---|
| 13:20 | 2.8 (3.9) | 2.2 (4.4) | 2.2 (4.4) | — | — |
| 13:25 | 6.9 (**18.6**) | 4.7 (5.1) | 4.9 (6.1) | 5.8 (8.6) | 4.5 (6.2) |
| 13:30 | 0.9 (0.9) | 14.4 (14.4) | 16.2 (16.2) | 14.9 (14.9) | 7.5 (14.9) |

* **While the database loads, the CPU is at about 4.5–7 %, or 0.7–1.1 vCPU.** Kraken2 reads the index with one thread, and the 15 other vCPUs are idle.
* The higher values are in the point where each job ends. In the 13:30 points of four instances the maximum equals the average, which suggests a single 1-minute sample before the instance stopped (not for Sample_A1, 7.5 / 14.9). **14–16 % in a single 1-minute sample matches all 16 threads busy for about 9–10 s** (9 s × 16 / 60 s ≈ 15 %), so the classification probably does use the 16 threads. Sample_BB's 18.6 % maximum at 13:25 fits the same. 5-minute points can't show this directly.
* **Average over the job: about 5–8 % ≈ 1 vCPU of 16.**

### Memory

Requested: 115,000 MiB (112.3 GiB) of the 128 GiB on the r5.4xlarge.

Used: **TBD.** Without `--memory-mapping`, Kraken2 loads the whole index into its own memory, so the process needs about 103 GiB plus the reads it is working on and its own buffers.

| Database | Index | Left under the 112.3 GiB request |
|---|---|---|
| Standard, June 2026 (probably in use) | 103.1 GiB | **~9 GiB** |
| Standard, Oct 2026 (current) | 109.4 GiB | **~3 GiB** |
| PlusPF, Oct 2026 | 116.1 GiB | Doesn't fit |

* Reading the file over NFS also fills the page cache, and the container's memory limit counts that cache. The kernel can drop cache before it kills the process, so the cache alone shouldn't cause an out-of-memory kill. But the process itself has to stay under the limit.
* **With the Oct 2026 release, the job would run with about 3 GiB to spare,** and a later release would not fit (Standard grew 6.3 GiB between the June and October 2026 releases). The Bakta job requests 122,880 MiB (120 GiB) on the same instance type, so Kraken2 can request about 7.7 GiB more without a larger instance. That gives about 10.6 GiB of headroom with the Oct 2026 release.
* The peak memory needs measuring before any change (section 6).

### Disk (EBS)

| Instance | EBS write, whole run | EBS write, first point | EBS read, whole run | EBS read, first point |
|---|---|---|---|---|
| Sample_BB (i-05dc…) | 2.35 GB | 2.24 GB | 1.30 GB | 0.78 GB |
| Sample_A4 (i-03af…) | 2.14 GB | 2.09 GB | 1.15 GB | 0.78 GB |
| Sample_A3 (i-0e40…) | 2.28 GB | 2.18 GB | 1.24 GB | 0.78 GB |
| Sample_A2 (i-0a9b…) | 2.20 GB | 2.12 GB | 1.17 GB | 0.85 GB |
| Sample_A1 (i-0b9d…) | 2.16 GB | 2.07 GB | 1.12 GB | 0.78 GB |

* **2.1–2.35 GB written and ~0.78 GB read in the first point**, with about 14,000 write and 10,800 read operations, on every instance. That is consistent with pulling and extracting the image, plus copying in the reads. Unlike the Bakta run, all 5 instances look the same.
* After that, EBS traffic is small (under 0.6 GB per point). The database doesn't go to disk. EBS is not a bottleneck.
* Peak disk space used: **TBD**.

### Network

| Instance | NetworkIn, whole run | NetworkOut, whole run |
|---|---|---|
| Sample_BB (i-05dc…) | 112.7 GB | 345 MB |
| Sample_A4 (i-03af…) | 112.6 GB | 264 MB |
| Sample_A3 (i-0e40…) | 112.6 GB | 296 MB |
| Sample_A2 (i-0a9b…) | 109.3 GB | 286 MB |
| Sample_A1 (i-0b9d…) | 112.1 GB | 269 MB |

* **NetworkIn ≈ 112 GB per job, almost all of it the EFS database read** (EFS: 110.8 GB per job). The trimmed reads from S3 are 0.35–0.53 GB per sample.
* NetworkOut: 264–345 MB. NFS request traffic is probably about 200 MB of that, if it scales with the bytes read as it did in the Bakta run (~85 MB for 48 GB). The rest is the output upload and the logs. The per-read output is not written to a file (no `--output`), so the rest is the report upload and the CloudWatch Logs traffic.

---

## 4. EFS database access

### Totals for the run (5 jobs)

| Metric | Value |
|---|---|
| Data read | **553.8 GB = 515.8 GiB** (≈ 103.2 GiB per job) in 527,978 operations |
| Average read size | **1,024 KiB in every minute** (the NFS maximum): purely sequential reads |
| Metadata | 282 operations |
| Data written | 0 |
| Metered I/O (Elastic) | 184.6 GB (reads are metered at one third of their size) |
| Peak read throughput | **1.65 GB/s at 13:27** (all clients) |
| Peak throughput utilization (`MeteredIOBytes` ÷ `PermittedThroughput`) | **51 %** at 13:27 (550 MB/s metered against 1 GiB/s) |
| Peak `PercentIOLimit` | 9.0 % |
| Client connections | 1 (13:22–13:23) → 3 (13:24–13:25) → 5 (13:26–13:27) → 6 (13:28, cause **TBD**) → 5 → 4 (13:30) → 1 (13:31) |

### By minute

| Minute (UTC) | Jobs reading | Read rate, all clients | Per job (approx.) | Utilization |
|---|---|---|---|---|
| 13:21 | 1 (BB, from 13:21:21) | 157 MB/s | ≈240 MB/s (partial minute: 9.4 GB in 39 s) | 4.9 % |
| 13:22 | 1 | 231 MB/s | 231 MB/s | 7.2 % |
| 13:23 | 1, then 3 from 13:23:38 | 413 MB/s | — | 12.8 % |
| 13:24 | 3 | 799 MB/s | 266 MB/s | 24.8 % |
| 13:25 | 3, then 5 from 13:25:44 | 937 MB/s | — | 29.1 % |
| 13:26 | 5 | 1,564 MB/s | 313 MB/s | 48.5 % |
| 13:27 | 5 | **1,650 MB/s** | 330 MB/s | **51.2 %** |
| 13:28 | 5 | 1,608 MB/s | 322 MB/s | 49.9 % |
| 13:29 | 5 until 13:29:05 (BB done), then 4 until 13:29:51–54, then 1 (A1) | 1,508 MB/s | — | 46.8 % |
| 13:30 | 1 (A1, until 13:30:44) | 364 MB/s | **≈495 MB/s (472 MiB/s), A1 alone** | 11.3 % |

### What this shows

* **Each job reads the whole index, once, from start to end.** About 103.2 GiB per job, in 1 MiB reads, with almost no metadata operations. This is Kraken2 loading `hash.k2d` into memory. Unlike Bakta, there are no small random reads. But a single sequential reader gets about (bytes in flight) ÷ (latency): the leader's ~240 MB/s fits about 8 MB in flight at the ~35 ms IA latency seen in the Bakta run. So IA latency and the NFS read-ahead window (`read_ahead_kb`) probably set the per-job rate. Not proven.
* **Jobs that followed read faster than the leader.** The leader (Sample_BB_S7) read about 230–240 MB/s on its own. With 3 jobs the average was about 266 MB/s each, and with 5 about 313–330 MB/s each. The jobs that started last loaded fastest (381–454 MB/s on average, section 2), and Sample_A1_S8, reading alone at the end on the part of the file the others had just read, reached about 495 MB/s (472 MiB/s). That supports the following-is-faster hypothesis (section 5) better than concurrency does. The file system wasn't the limit: it was at most at 51 % of `PermittedThroughput`. But the following jobs came close to the 500 MiB/s per-client limit of a One Zone file system: the averages stayed below it, and the per-client limit may cap the following jobs.
* **All data is in IA.** The IA latency probably limits the leader's read rate (first bullet), and the IA read charge applies to every byte ([cost_kraken2.md](cost_kraken2.md)).
* **The file system's limit is close.** At 330–495 MB/s per job, about 7–10 jobs loading at once would reach the 1 GiB/s metered limit (about 3.2 GB/s of reads). Bakta's Diamond stage reads ~136 MB/s per job from the same file system, so a mixed batch reaches the limit sooner.
* **What the 189.6 GiB on the file system is:** the Kraken2 index accounts for about 103 GiB. The rest, about 86 GiB, would be the Bakta database (about 64 GB, so ~60 GiB) and ~27 GiB of other files. The Kraken2 folder holds more than the `.k2d` files (for example the Bracken `kmer_distrib` files and `seqid2taxid.map`), so 103 GiB is a lower bound for it. This answers most of open question 10 in the [Bakta profiling](../bakta/profiling_bakta.md#10-open-questions-and-data-still-needed). Confirm it with `du -sh` on both database folders.

---

## 5. Variability and failures

### Spread

| Measure | Value |
|---|---|
| Run time (Batch) | min 4:26, **median 6:34**, max 8:10 (spread 3:45, 57 % of the median) |
| Start times | 13:21:18 → 13:25:51 (4:33 spread) |
| End times | 13:29:28 → 13:31:02 (**1:34 spread**) |

### Later jobs finish faster

| Start wave | Samples | Run time | Load time | Load rate | Load done |
|---|---|---|---|---|---|
| 1st, alone for 2:20 | Sample_BB_S7 | 8:10 | 7:44 | 239 MB/s | 13:29:05.3 |
| 2nd, 2:20 later | Sample_A4_S8, Sample_A3_S11 | 6:34, 6:37 | 6:13, 6:12 | 297 MB/s | **13:29:53.655, 13:29:53.887** |
| 3rd, 4:26–4:33 later | Sample_A2_S1, Sample_A1_S8 | 4:26, 5:11 | 4:04, 4:51 | 454, 381 MB/s | **13:29:50.8**, 13:30:44.1 |

**Three of the five loads converged.** Sample_A4_S8 and Sample_A3_S11 started together and finished loading 0.23 s apart. Sample_A2_S1 started 2:06 after them and finished loading 3 s *before* them. Only Sample_A1_S8, which started 6 s after Sample_A2_S1, finished later, by about 50 s. Sample_BB_S7, the leader, finished its load 45 s before the group. This is the same pattern as Bakta's Diamond stage, where three jobs finished within 0.08 s.

All 5 jobs read the same file, in the same order. **Likely explanation (a hypothesis, the same as for Bakta):** the first job to read a part of the file pays the IA latency, and jobs that read the same data shortly after are served faster, because EFS still has it at hand. With Kraken2 this effect is cleaner than with Bakta, because it doesn't depend on how similar the genomes are: every job reads the whole file, in the same order. The input reads don't explain the difference: Sample_BB_S7 has the largest read files, but the load (103 GiB) dwarfs the reads (0.35–0.53 GB). When the jobs catch up with each other, they read the same part of the file at the same time, and they finish together. **To confirm:** run one job on its own, then several together, and repeat with the database in Standard.

With 5 jobs and no repeats, the run-to-run noise is unknown.

### Failures

* **No failed status checks** (system or instance) on any instance.
* All 5 jobs finished and uploaded their report (74.5–78.7 KiB). Batch exit codes and attempts are **TBD**.
* Spot interruptions: not applicable if On-Demand (**TBD**). Out-of-memory kills: none; every job logged "Loading database information... done." and uploaded its report.

### Wrapper issues (reported, not fixed)

The production wrapper `/src/kraken2.sh` (not the script in [`tools/kraken2/src`](../../../tools/kraken2/src/kraken2.sh)) shows three problems:

1. **Kraken2's per-read output goes to CloudWatch Logs.** 196–197 of the last 200 events of every job are per-read lines (`C <read id> <taxid> <length> <k-mer map>`), averaging about 265 bytes. **Cause (confirmed):** the command has no `--output`, and without it Kraken2 writes one line per read pair to stdout (see the [tools/kraken2 README](../../../tools/kraken2/README.md#troubleshooting)). Batch sends stdout to CloudWatch Logs. **Measured:** the log group `/batch/biotools-kraken2` received **1,845,218 events and 535.8 MB** for the 5 jobs, about 290 bytes per event, almost all of it in the minutes 13:29 and 13:30, when the jobs finished loading. **Probably not everything arrived:** Sample_A1_S8 alone has at least 0.94 million read pairs, so, scaling by the trimmed read sizes, 5 jobs should have produced about 6–7 million lines (at least 4.7 million), not 1.85 million. Kraken2's final summary, which is printed after the per-read lines, is also missing from 4 of the 5 logs, and the filter used (`?sequences ?processed`) would have caught it, so this isn't a filter artefact. **Likely cause (a hypothesis):** the `awslogs` log driver in non-blocking mode, the ECS default unless set otherwise, drops lines when its buffer fills. Each job wrote about 265 MB to stdout in about 10 s without slowing Kraken2 down, which fits. Check the job definition's `logConfiguration` mode and the ECS `defaultLogDriverMode` account setting. In that mode, error lines can be lost too. The ingestion costs money ([cost_kraken2.md](cost_kraken2.md)), it hides the Kraken2 summary, and the per-read classification isn't kept anywhere else, so it is only (partly) in the logs. The fix is to pass `--output` with a file (and upload it if it is needed), or `--output -`, Kraken2's documented way to suppress the per-read output (`/dev/null` also works).
2. **`/src/kraken2.sh: line 111: warning: here-document at line 99 delimited by end-of-file (wanted 'EOF')`.** A here-document (the HTML report) is not terminated. The Bakta wrapper has the same problem.
3. **Two different jobs had the same name** (`aws-batch-biotoolkraken2-1`, for Sample_A4_S8 and Sample_A3_S11), and the names don't contain the sample. That makes the jobs harder to tell apart in the Batch console.

### Worst-case sample

Sample_BB_S7 (8:10): the first to start, and alone for its first 2:20, at the lowest read rate of the run (about 230–240 MB/s). Its extra time probably comes from its position in the batch, not from its reads.

---

## 6. Bottlenecks and recommendations

### Bottleneck per stage

| Stage | Share of run | Bottleneck | Evidence |
|---|---|---|---|
| **Database load (~103 GiB)** | **92–95 %** (4:04–7:44) | **EFS read throughput per client** | 1 MiB sequential reads at 239–454 MB/s per job; ~1 vCPU busy; the file system at most at 51 % of its limit |
| Classification, summary, per-read output, report upload | 4–6 % (14.5–19.4 s) | CPU (16 threads) and stdout | Classification 9.0 s on Sample_A1_S8, 9–14 s on all from the last per-read event; 14–16 % CPU in a single 1-minute sample ≈ 16 threads for ~9 s |
| Input download, wrapper | ~2 % (about 6 s) | — | Download 2.7–3.2 s; 3.2–3.4 s from the wrapper's end to Batch's stop |
| Image pull | Before the job starts (**TBD**) | — | ~2.2 GB to EBS in the first point |
| EBS | — | Not a bottleneck | Small after start-up |
| Memory | — | **Fits, with little headroom** | 103 GiB index under a 112.3 GiB request (~9 GiB left) |

**Overall: Kraken2 on this setup is bound by how fast it can read the database from EFS, not by the CPU.** Each sample pays the full 103 GiB load in time and in money.

### Recommendations

1. **Stop reading the whole database from EFS for every sample.** This is the main lever for both time and cost ([cost_kraken2.md](cost_kraken2.md)). Options to test, from least to most change:
   * **Several samples per instance, one EFS read.** Keep loading the index into memory, without `--memory-mapping`, which is slower in our setup. For a second sample to load from the page cache instead of from EFS, the cache has to keep the whole index while the first Kraken2 process holds its own copy, so about 2 × 103 GiB, and **the job's memory request must cover both (≈215 GiB)**, because the container's memory limit counts the page cache it fills. With today's 112.3 GiB limit, only about 9 GiB of the file stays cached, whatever the instance size. That means one job per r5.8xlarge (256 GiB), running 2–3 samples one after another inside that job. Separate jobs share the cache only if they use the same NFS mount (for example a host mount); per-task EFS volumes with TLS each get their own mount and don't share it. The mount method is **TBD**. (This 2× need comes from loading without `--memory-mapping`. With the index already in the page cache or on local disk, memory mapping would need it only once. That one case may be worth a test, without changing the decision for EFS.) Measure the load time and EFS bytes of the second sample.
   * **Database on local storage.** Keep a copy in S3 in the same region and copy it to the instance's NVMe at start-up (e.g. r5d.4xlarge). Reading from S3 within the region has no per-GB charge **if S3 is reached through a gateway endpoint**. Through a NAT gateway it costs about $0.048 per GB processed, about $5 per copy, which is more than the EFS charge it replaces. Measure the copy time and the run time. Don't use an EBS volume restored from a snapshot without pre-warming it: snapshots load lazily (see the [Bakta profiling](../bakta/profiling_bakta.md#recommendations)).
   * **A smaller database** (Standard-16, 14.9 GiB) for the species and contamination check before assembly. It changes the results, so validate it against Standard on these samples first, and agree it with whoever uses the report. The Oct 2026 Standard-16 is also a different release from the one in use. Changing the database breaks comparability with earlier results and with partner laboratories, like changing a tool version. Species confirmation shouldn't rest on Kraken2 alone in any case.
2. **Watch the throughput limit when scaling.** Five loads used 51 % of the file system's limit. About 7–10 Kraken2 loads at once, or fewer with Bakta's Diamond stage running at the same time on the same file system, would reach it, and every job would slow down. Spreading the job starts keeps the total under the limit, but if the following-is-faster hypothesis holds, it may make each job slower. The options in recommendation 1 avoid the problem.
3. **Decide the storage class together with Bakta.** The lifecycle is set per file system, so "Transition into Standard" would move the Bakta database too. To treat Kraken2 differently, it needs its own file system. Cost: see [cost_kraken2.md](cost_kraken2.md). The [Bakta decision](../bakta/cost_bakta.md#decision-keep-the-database-in-ia) was to stay in IA, but it counted only Bakta's savings. With both tools counted, the break-even is about 19 samples per month instead of 40–63 ([cost_kraken2.md](cost_kraken2.md#both-tools-together)).
4. **Raise the memory request before changing the database release.** The job requests 115,000 MiB (112.3 GiB) for a 103 GiB index. The Oct 2026 release (109.4 GiB) would leave under 3 GiB. Measure the peak memory, then raise the request to 122,880 MiB, as the Bakta job uses on the same instance type, before switching. Any release larger than about 115 GiB, and PlusPF (116.1 GiB), needs a larger instance (r5.8xlarge, 256 GiB).
5. **Don't change `--threads` or vCPU for speed.** The job runs `--threads 16`, but about 1 of 16 vCPUs is used, because the load is single-threaded and waits on EFS. Only the short classification uses the 16 threads. The instance size is set by memory: r5.4xlarge is the smallest r5 with more than 103 GiB.
6. **Instrument the next run:**
   * record the NFS layer on every job: mount options from `/proc/mounts` (`rsize`, `nconnect`, amazon-efs-utils version), `read_ahead_kb` (AWS recommends 15 MiB for EFS on kernel 5.4 and later), and `/proc/self/mountstats`. It is the cheapest test, and it doesn't change the tool;
   * make sure Kraken2's summary reaches the log (it should, once `--output` keeps the per-read lines out of stdout): it gives the classification time and the read count;
   * write down the database release (`RELEASE.txt` next to the index, as in the [database setup](../../database-setup/kraken2));
   * record the peak memory, for example with `/usr/bin/time -v`, or turn on the CloudWatch agent or Container Insights;
   * turn on detailed (1-minute) EC2 monitoring in the Batch launch template;
   * save `aws batch describe-jobs` for every job, including `createdAt` and attempts.
7. **Fix the wrapper** (add `--output` so the per-read output stays out of the logs, unterminated here-document, job names). Reported only; the code is not changed in this phase.

---

## 7. Pipeline view

* Kraken2 runs once per sample after trimming, as a species and contamination check before assembly. With one job per instance, the batch took 9:44 from the first start (13:21:18) to the last end (13:31:02). The end times are only 1:34 apart, because the later jobs loaded faster (section 5).
* Kraken2's share of the total time per sample, compared with fastp, SPAdes, Bakta and Roary: **TBD**.

---

## 8. Extra technical checks

| Check | Result in this run |
|---|---|
| I/O wait vs CPU time | **Mostly I/O wait.** About 1 vCPU busy out of 16 during the load, which is 92–95 % of the run |
| Memory over time, process vs page cache | **TBD.** Expected: the process grows to ~103 GiB during the load, and the page cache competes for the rest of the 128 GiB |
| Cold vs warm database | All 5 jobs were cold on the instance, with the database in IA. Later jobs loaded faster (section 5). Needed: a job on its own, a second job on the same instance, and a run with the database in Standard |
| Which stages use multiple threads | The load is single-threaded (~1 vCPU). Classification runs with `--threads 16`, and 14–16 % CPU in a single 1-minute sample fits all 16 busy for ~9 s. 1-minute monitoring would confirm it |
| Several jobs on one instance | Not tested. See recommendation 1 |
| Earlier result | The [earlier Kraken2 2.1.3 tests](https://github.com/ldipotetjob/kraken2/blob/kraken2aws_profilingfromv2.1.3/docs/Kraken2paramsonAWS/memory-mapping.md) report about 4 minutes per large sample on r5 instances with 60–100 GB of RAM and 16 threads, loading the database into memory. The database size isn't stated, so it can't be compared directly with the 4:26–8:10 here (103 GiB index) |
| Input sensitivity (read count) | The load doesn't depend on the input. After the load, time grows with input size (14.5 s at 330 MiB to 19.4 s at 501 MiB), and the classification ends 9.0–13.7 s after "done." (last per-read event, all 5 jobs). It is small next to the load |
| Startup overhead | Input download 2.7–3.2 s. Image pull: 2.1–2.35 GB written to EBS in the first point. Queue and boot **TBD** |
| Downstream effects | Report 74.5–78.7 KiB per sample. No per-read output file (no `--output`); 536 MB of per-read lines reached CloudWatch Logs for the 5 jobs |
| EFS storage class | **Measured: 100 % IA** (same file system as Bakta) |
| EFS One Zone placement | **TBD.** Confirm the Batch subnets are in the file system's AZ |

### Classification results (for reproducibility checks later)

**TBD:** the reports weren't in the sources. Sample_A1_S8: 423 sequences unclassified (0.04 %). In the per-read lines that were exported, the reads are assigned to *Pseudomonas* (taxid 286), *P. aeruginosa* (287) and the *P. aeruginosa* group (136841), as expected for these isolates.

---

## 9. Charts

The CloudWatch graph definitions (`*.kraken2.json`) are in [`graphs/`](graphs), the same set as for Bakta: CPUUtilization, NetworkIn and the EFS graphs (data read, operations per second, average read size, throughput utilization, client connections). They cover 13:18–13:35 UTC and mark the three load waves as bands, from the end of each input download to "Loading database information... done.". To see one, open CloudWatch → Metrics → All metrics → Source, paste the file, and apply. Screenshots (`*.png`) are still to take.

Still to make, from the data already collected except where noted:

1. **Gantt of the 5 jobs:** download / load / after load per job (section 2 table), coloured by start wave, showing three loads converging at 13:29:51–54.
2. **Run time and load rate against start time**, one point per job.
3. Memory over time (**needs the CloudWatch agent**).
4. EFS IA vs EFS Standard vs local disk vs page cache (second sample on r5.8xlarge), load time per job (**needs the follow-up runs**).

---

## 10. Open questions and data still needed

1. ~~Kraken2's stderr~~: partly answered. "Loading database information... done." is in every log (load times measured). The final summary ("N sequences (M Mbp) processed in X s", classified counts) reached CloudWatch for one job only. Still needed: the read count per sample, and why part of the output didn't reach CloudWatch.
2. **Database release** in production (June 2026 Standard expected from the bytes read) and its path on the file system.
3. ~~Job definition and Kraken2 options~~: answered (16 vCPU, 115,000 MiB; `--threads 16 --paired`, no `--output`, no `--memory-mapping`).
4. **Kraken2 version and image** (tag, size) in ECR.
5. **Batch `createdAt` and attempts** for the 5 jobs.
6. **Memory:** is the CloudWatch agent or Container Insights available on the compute environment?
7. ~~Trimmed read sizes~~: answered (330–501 MiB per sample, from the S3 download log). Read counts still needed (item 1).
8. ~~Where the per-read output goes and how big it is~~: answered (stdout, so CloudWatch Logs only; 535.8 MB and 1.85 million events for the 5 jobs).
9. **`du -sh`** of the Kraken2 and Bakta database folders, to account for the 189.6 GiB on the file system.
10. **EFS AZ vs Batch subnets** (One Zone).
11. Why there were 6 client connections at 13:28 with 5 jobs running (Bakta showed the same once).
12. **NFS mount:** options from `/proc/mounts` (`rsize`, `nconnect`, amazon-efs-utils version), `read_ahead_kb`, and `/proc/self/mountstats`, to test whether latency and read-ahead set the per-job load rate. Also whether the jobs mount EFS through the host or as per-task EFS volumes (TLS).
13. **Log driver mode:** `logConfiguration` of the job definition and the ECS `defaultLogDriverMode` setting (blocking or non-blocking), to explain the lost log lines.
14. **S3 path:** gateway endpoint or NAT gateway (matters for the S3 → NVMe option).

### Next profiling run, in priority order

1. Add `--output` (a file, or `-` to suppress it) so that Kraken2's summary reaches the log, and keep the job definition.
2. Record the NFS mount options, `read_ahead_kb` and `/proc/self/mountstats`, and test a larger `read_ahead_kb` (15 MiB) on one job.
3. One job alone on a fresh instance, then a second job on the same instance, to separate EFS-side caching from the start order.
4. 2–3 samples one after another inside one job on an r5.8xlarge (256 GiB), with a ~215 GiB memory request and without `--memory-mapping`. Measure the time per sample and the EFS bytes per sample, to check that the second load comes from the page cache.
5. Database copied from S3 to local NVMe (r5d.4xlarge): copy time and run time.
6. Standard-16 against Standard on the same 5 samples: run time and classification agreement.
7. Peak memory with the current and the Oct 2026 release.

## Data sources

| File | Content |
|---|---|
| `jobs.tsv` | `aws batch describe-jobs`: job ID, name, container instance, `startedAt`, `stoppedAt` |
| `ci.tsv` | CloudTrail `RegisterContainerInstance`: container instance → EC2 instance |
| `i-<instance-id>.log-events.kraken` (5 files) | Last 200 events of the job stdout from CloudWatch Logs |
| `<job-id>.kraken.summary.tsv` (5 files) | `aws logs filter-log-events` on `/batch/biotools-kraken2`: the non per-read lines of each job (S3 transfers, "Loading database information... done.", warnings) |
| `kraken2.logs.incomingbytes.json` | `aws cloudwatch get-metric-data`, namespace `AWS/Logs`, IncomingBytes and IncomingLogEvents of `/batch/biotools-kraken2`, 13:15–13:40 UTC |
| `i-<instance-id>.ec2.stats.kraken2.json` (5 files) | `aws cloudwatch get-metric-data`, namespace `AWS/EC2`, 13:20–13:31 UTC |
| `fs-05846c89e2da6b943.stats.kraken2.json` | `aws cloudwatch get-metric-data`, namespace `AWS/EFS`, 13:18–13:31 UTC |

Instance IDs: `i-03af2f62857655d64`, `i-05dcd73d4cab124f5`, `i-0a9b9340c95a31c35`, `i-0b9d8421ed2492e8e`, `i-0e40ae0063bb8ed3c`.
