# Bakta profiling on AWS

Status: **first full run analysed.** Built from one test batch (5 samples, 5 EC2 instances, one job each) on 2026-11-13. Sources: CloudWatch EC2 and EFS metrics, the job logs from CloudWatch Logs, and Bakta's own log file (`assembly.log`) for each job. CloudWatch graph definitions and screenshots are in [`graphs/`](graphs) (see [section 9](#9-charts)). Reviewed by the `bioinformatic-python` agent on 2026-11-15; its corrections are included. Cost and scaling are out of scope here. The cost analysis is in [cost_bakta.md](cost_bakta.md). Values marked **TBD** need data that isn't in these sources. See [section 10](#10-open-questions-and-data-still-needed).

## Key findings

1. **Bakta took 31:27–35:43 per genome (median 33:19), but used only about 2.4 of the 16 vCPUs on average.** The highest 5-minute maximum was 64 % of the instance (about 10 vCPUs); basic monitoring can't show shorter peaks.
2. **57 % of the run (median 19:07) is database lookups** in Bakta's SQLite annotation database on EFS, with the CPU almost idle. Two of them dominate: the UPS lookup for the CDS (7:52) and the UPS lookup for the sORF candidates (7:57). Together they are **47 % of the run**: each UPS lookup takes 62–99 ms. The other lookups (IPS, PSC, PSCC) are 5–10 times faster, at 8–17 ms each, and make up the remaining 10 %.
3. **The whole EFS file system is in Infrequent Access (IA).** `StorageBytes`: 203.6 GB in IA and 0.58 MB in Standard. The lifecycle has no "Transition into Standard", so reads do not bring files back. Every lookup reads from IA, which has higher latency than Standard.
4. **Diamond (PSC/PSCC search) is 19 % of the run (median 6:21)** and streams about 46.5 GB per job from EFS, with only 4–6 vCPUs busy. The 5 jobs together peaked at 680 MB/s of reads. That is only **21 % of the file system's throughput limit**, because EFS counts reads at one third against `PermittedThroughput`. So Diamond is not held back by the file system's limit. Each instance read at 100–145 MB/s; why it isn't faster (IA latency, the NFS client, or Diamond's own way of loading the database) is **not proven yet**.
5. **A second Diamond search, for pseudogene candidates, takes 11 % (3:38).** It reads the database from the instance's memory, not from EFS, so it shows how long Diamond takes even with the data local. The pseudogene logic itself takes under 1 s. The RNA stages take 10 % (3:21). Everything else, including CDS prediction, AMRFinderPlus, Pfam and export, adds up to about 1 minute.
6. **The jobs move in lockstep.** Three jobs started Diamond up to 8 s apart and finished it within 0.08 s of each other (10:49:01.700–.782); the two jobs that started last were the fastest. A likely cause, not yet proven: the first job to read a part of the database pays the IA latency, and jobs that read the same data shortly after (same species, so mostly the same database pages) are served faster.
7. **Cost: about $2.46 per sample, and EFS reads are 74 % of it.** See [cost_bakta.md](cost_bakta.md).
8. **The job wrapper has two bugs**, reported here and not fixed: it runs `bakta` a second time after it succeeds, and it has an unterminated here-document. See [section 5](#5-variability-and-failures).

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

Find where Bakta spends its time on AWS Batch when the **full** database is read from EFS. Collect the evidence needed to decide where the database should live and how big the job should be (vCPU, memory, `--threads`).

### In and out of scope

| In scope | Out of scope |
|---|---|
| Bakta only | Assembly (SPAdes), Pilon, Roary |
| Technical metrics: run time per stage, CPU, network, EBS, EFS | Scaling (thread count, genome size, instance families) |
| One setting: `--threads 16`, one job per instance | Cost: see [cost_bakta.md](cost_bakta.md) |

### Software

From the dependency check at the top of every `assembly.log`. The versions are the same in all 5 jobs.

| Item | Version |
|---|---|
| Bakta | **1.11.4** |
| Database | **full, version 6.0** (dated 2025-02-24) |
| Python | 3.10.22 |
| tRNAscan-SE | 2.0.13 |
| Aragorn | 1.2.41 |
| Infernal (`cmscan`) | 1.1.5 |
| PILER-CR | 1.6.0 |
| Pyrodigal | 3.7.1 |
| AMRFinderPlus | 4.2.7 (only `>=3.11.2` is pinned in [`environment.yaml`](../../../tools/bakta/environment.yaml)) |
| PyHMMER | 0.11.3 |
| Diamond | 2.2.8 |
| BLAST+ (`blastn`) | 2.17.0 |
| pyCirclize | 1.10.1 |
| Docker image | [`tools/bakta`](../../../tools/bakta), base Ubuntu 20.04. Tag and size **TBD** |

### Infrastructure

| Item | Value |
|---|---|
| Region | eu-west-1 |
| Compute | AWS Batch on EC2: 5 instances, one job per instance |
| Instance type | r5.4xlarge (16 vCPU = 8 physical cores with Hyper-Threading, 128 GiB RAM, EBS only, no instance store). Bakta sees `cores=16` |
| Host OS | Amazon Linux 2023, kernel 6.1.176 |
| vCPU / memory requested per job | 16 vCPU / 122,880 MiB (120 GiB) |
| Purchase option | On-Demand |
| Root / Docker storage | EBS (volume type and size **TBD**) |
| CloudWatch EC2 monitoring | Basic (5-minute points). Status checks are every minute |

### Database location: EFS

| Setting | Value |
|---|---|
| File system | `fs-05846c89e2da6b943`, mounted at `/mnt/efs/bakta_db` |
| Availability | **One Zone** (single Availability Zone) |
| Performance mode | General Purpose |
| Throughput mode | Elastic (`PermittedThroughput` = 1 GiB/s of metered throughput for the whole run; reads count at one third, so about 3 GiB/s of reads) |
| Lifecycle: into IA | 14 days since last access |
| Lifecycle: into Archive | None |
| Lifecycle: back into Standard | **None** (a file in IA stays in IA after it is read) |
| Data stored during the run | 203.6 GB, of which **203.6 GB in IA** and 0.58 MB in Standard |

### Bakta command

The same on every job:

```
bakta /data/in/assembly.polish.fasta --db /mnt/efs/bakta_db --output /data/out \
      --verbose --force --threads 16 --min-contig-length 500 --prefix assembly
```

No `--skip-*` options (confirmed in `assembly.log`), so every step ran: tRNA, tmRNA, rRNA, ncRNA, ncRNA regions, CRISPR, CDS, pseudogenes, sORF, gaps, oriC/oriV/oriT, feature filters and the circular plot.

### Samples and instances

| Sample | Instance | Job start (wrapper) |
|---|---|---|
| Sample_A1_S8 | `i-04366523d15f5d0da` | 10:28:08 |
| Sample_A3_S11 | `i-087b88d15d0f9ad60` | 10:30:15 |
| Sample_A2_S1 | `i-082ba1ed032b65262` | 10:30:16 |
| Sample_BB_S7 | `i-0dde0a81430178b0b` | 10:32:28 |
| Sample_A4_S8 | `i-072ae09e3f8a8a46a` | 10:32:30 |

### Test dataset

All 5 are *Pseudomonas aeruginosa* draft assemblies (SPAdes followed by Pilon). Values are from Bakta's genome statistics, after `--min-contig-length 500` removed the short contigs.

| Sample | Contigs in → kept | Size (bp) | N50 (bp) | N90 (bp) | GC (%) | Coding density (%) |
|---|---|---|---|---|---|---|
| Sample_A1_S8 | 144 → 77 | 6,424,797 | 196,984 | 73,631 | 66.4 | 89.3 |
| Sample_A2_S1 | 104 → 65 | 6,461,188 | 236,245 | 92,106 | 66.3 | 89.4 |
| Sample_A3_S11 | 127 → 68 | 6,427,809 | 236,249 | 92,106 | 66.4 | 89.3 |
| Sample_A4_S8 | 136 → 70 | 6,391,900 | 270,827 | 77,428 | 66.2 | 89.3 |
| Sample_BB_S7 | 66 → 36 | 6,354,705 | 396,469 | 155,236 | 66.5 | 89.9 |

The panel is narrow. Size varies by only 1.7 % (6.35–6.46 Mbp) and GC is almost the same. The genomes differ mainly in fragmentation (36–77 contigs). This run can't show how run time depends on genome size.

### Test design

| Item | Value |
|---|---|
| Repeats | None: each genome ran once |
| Cold or warm | All cold on the instance: a new instance per job, so the page cache was empty and the database came from EFS (IA) |
| Concurrency | 5 jobs in parallel, started 10:28–10:32, all reading the same EFS file system |
| Jobs per instance | 1 |

### How we measured

| Source | What it gives | Resolution |
|---|---|---|
| Bakta `assembly.log` (one per job) | Start and end of every stage, dependency versions, settings | Millisecond timestamps on every line |
| CloudWatch Logs (job stdout) | Wrapper steps (S3 download and upload), Bakta's summary | Event timestamps |
| CloudWatch `AWS/EC2`, per instance | CPUUtilization (avg, max), NetworkIn/Out, packets, EBS read/write bytes and ops, status checks | 5 min (basic monitoring); status checks every 1 min |
| CloudWatch `AWS/EFS` | Data and metadata read/write bytes and ops, TotalIOBytes, MeteredIOBytes, PermittedThroughput, PercentIOLimit, ClientConnections, StorageBytes by storage class | 1 min |

Window for CloudWatch metrics: `2026-11-13T10:26:00Z` to `2026-11-13T11:10:00Z`, the same for EC2 and EFS. It covers all 5 jobs from start to end.

**How stage times are measured:** Bakta writes a log line when a step ends (e.g. `UPS - looked-up=5656`). A stage's time is the gap between its end line and the end line of the stage before it.

### Limitations

* **5-minute EC2 points.** CPU can't be matched to stages shorter than ~5 minutes.
* **No memory metric.** EC2 doesn't report memory. That needs the CloudWatch agent or Container Insights.
* **No Batch timestamps.** Queue wait, instance start-up and image pull can't be measured.
* **Shared EFS.** The 5 jobs ran together. The EFS numbers are totals over 5 clients, and the jobs affected each other (section 5).
* One run, one thread setting, one time of day, and the database was in IA the whole time.
* Bakta's stdout is buffered, so the CloudWatch log arrives in two blocks. That doesn't matter here because `assembly.log` has every timestamp.

---

## 2. Time breakdown per job

### From job submission to end

| Phase | Source | Value |
|---|---|---|
| Queue wait + instance start-up (`createdAt` → `startedAt`) | Batch `describe-jobs` | **TBD** |
| Image pull and extraction | ECS events | **TBD.** The first 5-minute EBS point of each instance shows 3.8–5.6 GB written, consistent with image layers being extracted (section 3) |
| Database mount (EFS) | Near instant. The first reads are inside Bakta's time | — |
| Input download from S3 (6.1–6.3 MiB) | Wrapper log | **2.1–2.2 s** |
| Bakta start-up (Python, settings, database and dependency checks) | `assembly.log` | **~3 s** |
| Bakta annotation | `assembly.log` | **31:27–35:43** (median 33:19) |
| Second `bakta` call (fails, see section 5) | Wrapper log | ~1 s |
| Output upload to S3 (93–94 MiB in 16 files, then an 8 MiB GFF) | Wrapper log | ~2.5 s |
| **Container run time (wrapper start → end)** | Wrapper log | **31:34–35:50** |

Per job:

| Sample | Wrapper start | Bakta log start | Bakta log end | Bakta time (log) | Bakta's printed time | Wrapper end | Total |
|---|---|---|---|---|---|---|---|
| Sample_A1_S8 | 10:28:08 | 10:28:12 | 11:03:54 | 35:43 | 35:20 | 11:03:58 | 35:50 |
| Sample_A3_S11 | 10:30:15 | 10:30:19 | 11:03:38 | 33:19 | 32:56 | 11:03:41 | 33:26 |
| Sample_A2_S1 | 10:30:16 | 10:30:20 | 11:03:38 | 33:19 | 32:56 | 11:03:42 | 33:26 |
| Sample_BB_S7 | 10:32:28 | 10:32:32 | 11:05:12 | 32:41 | 32:18 | 11:05:16 | 32:48 |
| Sample_A4_S8 | 10:32:30 | 10:32:34 | 11:04:01 | 31:27 | 31:03 | 11:04:04 | 31:34 |

**Bakta accounts for over 99 % of the container run time.** S3 transfers and the wrapper add about 6 s in total. The time Bakta prints at the end ("Annotation successfully finished in …") is 22–24 s shorter than the time between its first and last log lines. This report uses the log times.

### Bakta stages

Seconds per stage, from `assembly.log`. The share is the median stage time divided by the median total.

| Stage | Sample_A1 | Sample_A3 | Sample_A2 | Sample_BB | Sample_A4 | Median | Share |
|---|---|---|---|---|---|---|---|
| Start-up (settings, DB check, dependencies, import) | 1.7 | 1.4 | 1.5 | 1.6 | 1.4 | 1.5 | 0.1 % |
| tRNA (tRNAscan-SE) | 41.6 | 37.0 | 38.8 | 27.4 | 36.6 | 37.0 | 1.9 % |
| tmRNA (Aragorn) | 3.6 | 3.6 | 3.6 | 3.6 | 3.6 | 3.6 | 0.2 % |
| rRNA (Infernal) | 17.2 | 16.7 | 18.4 | 17.7 | 18.1 | 17.7 | 0.9 % |
| ncRNA (Infernal) | 114.6 | 114.1 | 113.5 | 96.7 | 107.3 | 113.5 | 5.7 % |
| ncRNA regions (Infernal) | 28.8 | 27.2 | 27.1 | 24.6 | 26.9 | 27.1 | 1.4 % |
| CRISPR (PILER-CR) | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 | 0.1 % |
| CDS prediction (Pyrodigal) | 3.0 | 3.0 | 3.0 | 3.1 | 3.0 | 3.0 | 0.2 % |
| Spurious CDS filter (PyHMMER) | 0.7 | 0.7 | 0.7 | 0.6 | 0.7 | 0.7 | 0.0 % |
| **CDS: UPS lookup** | **578.0** | **464.9** | **472.3** | **503.5** | **440.7** | **472.3** | **23.6 %** |
| CDS: IPS lookup | 70.5 | 63.0 | 59.9 | 89.0 | 81.8 | 70.5 | 3.5 % |
| **PSC + PSCC search (Diamond)** | **387.9** | **388.8** | **380.7** | **328.4** | **324.1** | **380.7** | **19.0 %** |
| CDS: PSC lookup | 46.1 | 46.2 | 46.1 | 50.2 | 42.5 | 46.1 | 2.3 % |
| CDS: PSCC lookup | 83.3 | 81.0 | 84.2 | 79.9 | 79.4 | 81.0 | 4.1 % |
| AMRFinderPlus | 9.5 | 10.1 | 9.8 | 9.6 | 9.6 | 9.6 | 0.5 % |
| Expert protein sequences (Diamond) | 2.3 | 2.4 | 2.3 | 2.4 | 2.3 | 2.3 | 0.1 % |
| **Pseudogene candidates (Diamond) + pseudogene detection (< 1 s)** | **218.3** | **206.5** | **224.1** | **207.4** | **217.7** | **217.7** | **10.9 %** |
| Hypotheticals: Pfam (PyHMMER) | 1.9 | 2.3 | 1.9 | 3.7 | 1.9 | 1.9 | 0.1 % |
| sORF prediction and filter | 5.9 | 5.6 | 5.8 | 6.2 | 5.6 | 5.8 | 0.3 % |
| sORF spurious filter | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.0 % |
| **sORF: UPS lookup** | **499.1** | **496.1** | **475.7** | **477.0** | **454.6** | **477.0** | **23.9 %** |
| sORF: IPS, PSC, PSCC lookups | 0.5 | 0.5 | 0.6 | 0.3 | 0.4 | 0.5 | 0.0 % |
| Gaps, oriC/oriV/oriT, filters, locus tags | 2.1 | 2.0 | 2.2 | 2.1 | 2.0 | 2.1 | 0.1 % |
| Export (TSV, GFF3, GenBank, EMBL, FASTA) | 1.8 | 1.8 | 1.8 | 1.8 | 1.8 | 1.8 | 0.1 % |
| Circular plot (pyCirclize) | 21.5 | 21.5 | 21.9 | 21.5 | 22.0 | 21.5 | 1.1 % |
| Hypotheticals TSV/FAA, JSON, clean-up | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 | 0.0 % |
| **Total** | **2,142.5** | **1,999.1** | **1,998.7** | **1,960.7** | **1,886.6** | **1,998.7** | 100 % |

### Grouped

| Group | Stages | Median | Share | What limits it |
|---|---|---|---|---|
| **Database lookups (SQLite on EFS)** | UPS, IPS, PSC, PSCC for CDS and sORF | **19:07** | **57 %** | **EFS latency.** CPU ≈ 0.1 vCPU |
| Diamond PSC/PSCC search | | 6:21 | 19 % | **EFS read speed per instance** (cause not proven). ~46.5 GB read per job, 4–6 vCPU busy |
| Pseudogene candidates (second Diamond search) | | 3:38 | 11 % | Diamond itself, ~4–6 vCPU, on data already in memory (EFS barely used) |
| RNA stages | tRNA, tmRNA, rRNA, ncRNA, ncRNA regions, CRISPR | 3:21 | 10 % | CPU, 4–5 vCPU on average, highest 5-min max ~10 vCPU |
| Everything else | Start-up, CDS prediction, AMRFinderPlus, Pfam, sORF prediction, ori, export, plot | 0:52 | 3 % | — |

**How fast the lookups are:**

| Lookup | Sequences looked up | Time | Rate | Time per lookup |
|---|---|---|---|---|
| CDS UPS | 5,826–5,890 (CDS minus spurious ORFs) | 441–578 s | 10–13 per s | **76–99 ms** |
| sORF UPS | 6,912–7,353 | 455–499 s | 14.5–16 per s | **62–69 ms** |
| CDS IPS (Sample_A1) | 5,620 | 70.5 s | 80 per s | 12.5 ms |
| CDS PSC (Sample_A1) | 5,807 | 46.1 s | 126 per s | 7.9 ms |
| CDS PSCC (Sample_A1) | 5,693 | 83.3 s | 68 per s | 14.6 ms |

A UPS lookup finds a sequence by its hash (an MD5 digest) in the largest table of the SQLite database, so each lookup lands on a random page; that explains why UPS is much slower than the other lookups. With EFS seeing about 28 reads per second per job in these stages, each UPS lookup makes about 2 EFS reads of about 35 ms each. That fits IA latency.

The measured rate means **about one read in flight at a time**. Bakta 1.11 may run lookups on a thread pool sharing one SQLite connection (to be checked in the image's Bakta source); if so, the threads are waiting on each other, which means `--threads` can't speed up the lookups, but a change in how the database is opened could.

The sORF step is a lot of work for a small result: 455–499 s of lookups for 6,900–7,350 candidates, which leaves **2–4 sORFs per genome**.

---

## 3. Resource use

### CPU

CPUUtilization (%) of the instance, 5-minute average. 100 % = 16 vCPU, so 6.25 % = 1 vCPU. The stage in bold is the one that takes most of each 5-minute point.

| Point (UTC) | Sample_A1 (i-0436…) | Sample_A3 (i-087b…) | Sample_A2 (i-082b…) | Sample_BB (i-0dde…) | Sample_A4 (i-072a…) | Main stage (first three / last two jobs) |
|---|---|---|---|---|---|---|
| 10:30 | 24.4 | 29.7 | 31.3 | 18.7 | 20.4 | RNA stages / start-up and RNA |
| 10:35 | **0.6** | **0.6** | **0.5** | 16.1 | 14.3 | **CDS UPS lookup** / RNA, then UPS |
| 10:40 | 18.1 | 17.2 | 12.2 | **0.5** | **0.6** | UPS → IPS → Diamond / **CDS UPS lookup** |
| 10:45 | 23.8 | 26.7 | 29.0 | 32.0 | 38.3 | Diamond |
| 10:50 | 28.0 | 26.9 | 26.1 | 23.6 | 25.4 | PSC/PSCC lookups → pseudogene candidates (Diamond) |
| 10:55 | 4.9 | 2.7 | 8.5 | 18.6 | 10.6 | **sORF UPS lookup** / pseudogene candidates → sORF |
| 11:00 | 1.2 | 1.2 | 1.2 | 0.5 | 1.2 | **sORF UPS lookup** |
| 11:05 | — | — | — | 2.0 | — | export |
| **Highest 5-min max** | 63.4 | 62.7 | 57.7 | 62.4 | 64.0 | |

* **During UPS lookups the CPU is at 0.5–1.2 %, about 0.1–0.2 vCPU.** Bakta is waiting on EFS.
* Both Diamond searches: 24–38 % ≈ 4–6 vCPU of 16. The second one runs on data already in memory and is still at this level, so Diamond doesn't use all 16 threads even without waiting on EFS.
* RNA stages: 24–31 % ≈ 4–5 vCPU; the highest 5-minute maximum is 64 % ≈ 10 vCPU.
* **Average over the job: 14–16 % ≈ 2.2–2.5 vCPU out of 16 requested.** With 5-minute points, short bursts above 64 % can't be ruled out.
* CPU time vs wall time: about 2.4 vCPU × 33 min ≈ 80 vCPU-minutes per job. On 16 vCPUs that is 5 minutes of work, spread over 33 minutes (see section 8).

### Memory

Requested: 122,880 MiB (120 GiB) of the 128 GiB on the r5.4xlarge.

Used: **TBD.** EC2 doesn't report memory. Note for the measurement: each job streams about 46.5 GB from EFS during the Diamond stage, and the NFS client caches it in the page cache. Container memory will include that cache, so report process memory (RSS) and page cache separately. **The cache matters for speed:** the pseudogene-candidate search reads the same protein database again and costs almost no EFS traffic only because ~47 GB stayed cached. A smaller instance or a tighter memory limit could force that second read back to EFS.

### Disk (EBS)

| Instance | EBS write, whole run | EBS write, first 5-min point | EBS write, last point (output) | EBS read |
|---|---|---|---|---|
| Sample_A1 (i-0436…) | 0.18 GB* | 8.5 MB* | 121 MB | 0.6 MB |
| Sample_A3 (i-087b…) | 3.99 GB | 3.80 GB | 128 MB | 19.9 MB |
| Sample_A2 (i-082b…) | 5.51 GB | 5.33 GB | 120 MB | 19.6 MB |
| Sample_BB (i-0dde…) | 5.83 GB | 5.65 GB | 122 MB | 780 MB |
| Sample_A4 (i-072a…) | 5.60 GB | 5.41 GB | 135 MB | 781 MB |

\* Sample_A1 started at 10:28, so its start-up point (10:25–10:30) is before the query window.

* **3.8–5.6 GB written in the first point.** This is consistent with the container image being pulled and extracted, plus Bakta's first temporary files. It doesn't fully add up, though: Sample_A4_S8 wrote the same 5.4 GB and read the same ~780 MB from EBS as Sample_BB_S7, but received only 93 MB over the network, against ~2 GB for Sample_BB_S7. Breakdown **TBD** (image size from ECR, ECS events).
* **During the run: 7–25 MB per 5 minutes.** Bakta's temporary files are small. EBS is not a bottleneck.
* **At the end: 120–135 MB**, which matches the outputs (93–94 MiB plus the 8 MiB GFF). Writing them takes under 3 s (section 2).
* `EBSIOBalance%` and `EBSByteBalance%` are empty, as expected: r5.4xlarge has fixed EBS bandwidth and no burst credits.
* Peak disk space used: **TBD**.

### Network

| Instance | NetworkIn, whole run | NetworkOut, whole run | of which output upload (last point) |
|---|---|---|---|
| Sample_A1 (i-0436…) | 47.5 GB | 200 MB | 114 MB |
| Sample_A3 (i-087b…) | 47.5 GB | 202 MB | 115 MB |
| Sample_A2 (i-082b…) | 47.5 GB | 199 MB | 115 MB |
| Sample_BB (i-0dde…) | 49.4 GB | 196 MB | 110 MB |
| Sample_A4 (i-072a…) | 47.5 GB | 199 MB | 114 MB |

* **NetworkIn ≈ 47.5 GB per job, almost all EFS database reads,** and almost all of that during the Diamond stage. The EFS total for the run is 239.9 GB, or 48 GB per job. Input from S3 is only ~6 MiB.
* The extra ~2 GB on Sample_BB_S7 is in its first point and is probably the image pull. The other instances pulled theirs before 10:30 or have it cached (**TBD**).
* NetworkOut: ~110–115 MB of output upload, plus ~85 MB of NFS request traffic.
* Split by database / input / output / image: database ≈ 47.5 GB, input ≈ 6 MiB, output ≈ 102 MiB, image **TBD**.

---

## 4. EFS database access

### Totals for the run (5 jobs)

| Metric | Value |
|---|---|
| Data read | **239.9 GB** (≈ 48 GB per job) in 389,894 operations |
| Metadata | 62,038 operations, 254 MB |
| Data written | 0 (the database is read-only, as expected) |
| Metered I/O (Elastic) | 80.2 GB (reads are metered at one third of their size) |
| Peak read throughput | **680 MB/s at 10:47** (all clients) |
| Peak throughput utilization (`MeteredIOBytes` ÷ `PermittedThroughput`) | **21 %** at 10:47 (227 MB/s metered against 1 GiB/s) |
| Peak `PercentIOLimit` | 3.7 % |
| Client connections | 1 → 3 → 5 at 10:29 / 10:31 / 10:33, then 5 until 11:04 (6 for one minute at 10:56, cause **TBD**), and 1 at 11:05 |

### By time window and Bakta stage

The last two jobs ran about 2 minutes behind the first three, so the windows overlap a little.

| Window (UTC) | Bakta stage (from `assembly.log`) | Data read | Read ops/s (all) | Avg read size | Metadata ops/s |
|---|---|---|---|---|---|
| 10:28–10:35 | Start-up, RNA stages | 0.93 GB | 27 | 69 KiB | 41 |
| 10:36–10:41 | **CDS UPS lookup** | 1.65 GB | 140 | **32.0 KiB** | ~0 |
| 10:42–10:50 | **Diamond PSC/PSCC** | **232.7 GB** | 459 | **916 KiB** | ~0 |
| 10:51–10:54 | PSC/PSCC lookups, AMRFinderPlus, pseudogene candidates (Diamond from memory) | 1.03 GB | 38 | 110 KiB | 26 |
| 10:55–11:05 | **sORF UPS lookup**, export | 3.59 GB | 105 | 51 KiB (32 KiB from 10:57) | 54 |

### What this shows

* **All data is in Infrequent Access.** On EFS, IA reads have higher first-byte latency than Standard (tens of milliseconds vs about a millisecond) and are charged per GB read. Because "Transition into Standard" is set to None, the database stays in IA however often it is read. Any database file not read for 14 days goes to IA. Over this run nearly everything (203.6 GB) was already there.
* **The lookup stages are bound by latency, not throughput.** About 28 small reads per second per job, ~2 per lookup, with the CPU almost idle. Bakta waits for one read at a time. This is the pattern of single-threaded SQLite lookups on NFS, and IA latency makes it worse. A low `PercentIOLimit` does not mean EFS is not the bottleneck here.
* **The 32 KiB average is exact (32,768 bytes) over many minutes.** NetworkIn on the instances in those minutes is much lower than the EFS `DataReadIOBytes` (e.g. 30–57 MB per instance per 5 min during the CDS UPS lookup, against ~250–300 MB/min on EFS for all clients). So the real reads are about 4 KiB (one SQLite page) and EFS counts each one as at least 32 KiB. The operation count is reliable. The byte count in the lookup stages is likely an overestimate.
* **Diamond is the largest data transfer: ~46.5 GB per job in 5:24–6:29** (100–145 MB/s per job), in reads of almost 1 MiB (the NFS maximum). That fits Diamond streaming the PSC and PSCC protein databases. It is still not CPU-bound: only 4–6 of 16 vCPUs are busy. **Diamond's time depends on the database, not on the number of queries:** Sample_BB_S7 searched 543 proteins (the others 233–240) and was among the fastest (328 s).
* **Shared throughput.** EFS compares *metered* throughput with `PermittedThroughput`, and reads are metered at one third of their size. With 5 jobs in the Diamond stage at the same time, utilization peaked at 21 % as a one-minute average (higher peaks within the minute are possible). At ~136 MB/s of reads per job, about 20–23 jobs in the Diamond stage at once would reach the limit. Each job read at 100–145 MB/s, well below the 500 MiB/s per-client limit of a One Zone file system, so neither limit explains Diamond's speed. **The cause is not proven.** ~136 MB/s in ~1 MiB reads at ~35 ms fits about 5 MB in flight (an NFS read-ahead window), but it equally fits a single-connection client limit or Diamond loading its database serially. Mount options, `read_ahead_kb` and Diamond's own timings (`-v`) are needed to tell.
* **Metadata operations during the sORF lookups.** Metadata ops are ~0 per second during the CDS UPS lookup but 70–80 per second during the sORF UPS lookup (10:57–11:02), about one per sORF lookup. The cause is unknown: possibly SQLite checking the file for changes, or NFS refreshing file attributes. Opening the database as read-only and immutable (`immutable=1`) is worth testing. `/proc/self/mountstats` would show the operation types.
* **One Zone.** The file system has a single mount target, in one Availability Zone. Instances in other AZs of the region can still mount it, but every byte crosses AZs: more latency, and a cross-AZ data charge ([cost_bakta.md](cost_bakta.md)). Which subnets the compute environment uses is **TBD**.

---

## 5. Variability and failures

### Spread

| Measure | Value |
|---|---|
| Bakta time (log) | min 31:27, **median 33:19**, max 35:43 (spread 4:16, 13 %) |
| Start times | 10:28:12 → 10:32:34 (4:22 spread) |
| End times | 11:03:38 → 11:05:12 (**1:34 spread**) |

The stages that vary most between jobs read the database from EFS: CDS UPS lookup (441–578 s), sORF UPS lookup (455–499 s), Diamond (324–389 s) and IPS lookup (60–89 s). Some CPU-bound stages (Pyrodigal, AMRFinderPlus, plot, rRNA) take the same time to within 1 s on every job, but the RNA stages vary with the input: tRNA 27–42 s and ncRNA 97–115 s, both fastest on Sample_BB_S7 (36 contigs).

### The jobs move in lockstep

Wall-clock time when each job's main stages ended:

| Sample | Bakta start | CDS prediction done | CDS UPS lookup done | Diamond | Pseudogene candidates | sORF UPS lookup done |
|---|---|---|---|---|---|---|
| Sample_A1_S8 | 10:28:12 | 10:31:44 | 10:41:23 | 10:42:33.9 → **10:49:01.753** | 10:51:23 → 10:55:01 | 11:03:28 |
| Sample_A3_S11 | 10:30:19 | 10:33:44 | 10:41:30 | 10:42:33.0 → **10:49:01.782** | 10:51:21 → 10:54:47 | 11:03:12 |
| Sample_A2_S1 | 10:30:20 | 10:33:48 | 10:41:41 | 10:42:41.0 → **10:49:01.700** | 10:51:24 → 10:55:08 | 11:03:11 |
| Sample_A4_S8 | 10:32:34 | 10:35:53 | 10:43:14 | 10:44:36 → 10:50:00 | 10:52:14 → 10:55:52 | 11:03:34 |
| Sample_BB_S7 | 10:32:32 | 10:35:28 | 10:43:52 | 10:45:21 → 10:50:50 | 10:53:12 → 10:56:39 | 11:04:46 |

* Sample_A1_S8 finished CDS prediction 2 minutes before the next two jobs, but its UPS lookup took 2 minutes longer (578 s), so all three finished it within 18 s of each other.
* Those three jobs started Diamond up to 8 s apart and finished it **within 0.08 s of each other** (10:49:01.700–.782). Their PSC lookups then also ended within 0.13 s (10:49:47.823–.954).
* The two jobs that started last had the shortest Diamond stages (324–328 s vs 381–389 s) and, for Sample_A4_S8, the shortest UPS lookup (441 s).

**Likely explanation (a hypothesis):** all 5 genomes are *P. aeruginosa*, so the jobs look up mostly the same database records and Diamond reads the same files. The first job to read a part of the database waits for IA. Jobs that read the same data shortly after are served faster, because EFS still has it at hand. A job that falls behind speeds up, and the leader is slowed down. Evidence for it: the jobs that followed read faster during Diamond (~144 MB/s against ~120 MB/s for the leaders), and the UPS read rate per job rose as more jobs joined (about 16 reads/s with only Sample_A1_S8 running at 10:32, ~25 at 10:36, ~31 at 10:41). Not ruled out: each instance warming up its own copy of the SQLite index pages over time, which would also speed jobs up. EFS-side caching is not documented as specific to IA, so the same effect may happen in Standard.

Sample_BB_S7 is genetically the most distinct of the five: fewer UPS hits (5,288 against ~5,600), more PSC hits (486 against ~190) and 13 pseudogenes. It shares fewer database pages with the others, which fits it gaining less from the other jobs. Sample_A1–4 look nearly identical (same tRNA, ncRNA and sORF counts), so this panel probably shows more cross-job speed-up than a batch of diverse isolates would. **To confirm:** run one job on its own, then a second job on the same instance, and repeat with the database in Standard.

With 5 jobs and no repeats, median and slowest-5 % can't be measured reliably. Run-to-run noise on the same genome is unknown.

### Failures

* **No failed status checks** (system or instance) on any instance.
* All 5 jobs finished: "Annotation successfully finished" and a valid GFF for each (`OK: … (contigs: N, CDS: N)`). The 5 `assembly.log` files contain only `INFO` lines, no warnings or errors.
* Spot interruptions: not applicable (On-Demand). Retries and out-of-memory kills: none seen in the logs. Batch attempts **TBD**.

### Wrapper issues (reported, not fixed)

The production wrapper `/src/bakta.sh` (not the 3-line [`tools/bakta/src/bakta.sh`](../../../tools/bakta/src/bakta.sh) in this repo) shows two problems in every job log:

1. **`bakta` runs a second time after the first run succeeds.** About 1 s after "Annotation successfully finished", the log shows `ERROR: output path (/data/out) already exists! Either provide a non-existent new path or force overwriting it via '--force'`. A second `bakta` call without `--force` fails right away. It costs only ~1 s, but it is an error in every job log and could hide real failures.
2. **`/src/bakta.sh: line 103: warning: here-document at line 91 delimited by end-of-file (wanted 'EOF')`.** A here-document (the HTML report) is not terminated.

### Worst-case sample

Sample_A1_S8 (35:43): the most fragmented assembly (144 contigs before filtering, 77 after) and the first to start. Almost all of its extra time is in the CDS UPS lookup (+106 s over the median), the stage where it led the other jobs and read alone at first.

---

## 6. Bottlenecks and recommendations

### Bottleneck per stage

| Stage group | Share of run | Bottleneck | Evidence |
|---|---|---|---|
| **UPS lookups (CDS and sORF)** | **47 %** | **EFS latency (IA)**, about one read in flight | 62–99 ms per lookup; CPU ≈ 0.1 vCPU; ~28 small reads/s per job |
| Other lookups (IPS, PSC, PSCC) | 10 % | EFS latency, smaller effect | 8–17 ms per lookup |
| **Diamond PSC/PSCC** | **19 %** | **EFS read speed per instance** (cause not proven) | 46.5 GB per job at 100–145 MB/s; only 4–6 vCPU busy; file system at only 21 % of its limit and far below the per-client limit |
| Pseudogene candidates (second Diamond search) | 11 % | Diamond itself, from memory | ~4–6 vCPU; NetworkIn only ~100 MB in that window. Sets a floor of ~3.6 min for a Diamond scan even with local data |
| RNA stages | 10 % | CPU, partly parallel | 4–5 vCPU on average; varies with the input (ncRNA 97–115 s) |
| Everything else | 3 % | CPU, single-threaded parts | Circular plot alone 22 s |
| S3 transfers, wrapper | < 1 % | — | ~6 s per job |
| EBS, network bandwidth | — | Not a bottleneck | Small EBS traffic; NetworkIn far below the instance's bandwidth |
| Memory | — | **Unknown** | Not measured |

**Overall: Bakta on this setup is I/O-bound on the EFS database, not CPU-bound.** About three quarters of the run (lookups and the first Diamond search) is spent waiting on EFS.

### Recommendations

1. **Get the database out of IA.** Either set "Transition into Standard" to *On first access*, or turn off the IA transition for the database file system. Then re-run the same 5 genomes and compare the UPS lookups (15:49 per job now) and Diamond (6:21). This is the smallest change and directly tests the latency finding. Cost effect: see [cost_bakta.md](cost_bakta.md).
2. **Test the database on local storage.** Use the same genomes with the database copied to instance-store NVMe (e.g. r5d or m5d) or to an EBS gp3 volume, or baked into an AMI or snapshot (pre-warmed, because snapshots load lazily). Small random reads, which are 57 % of the run, are where local disk gains most over NFS. Diamond won't drop to near zero: the second Diamond search took ~3.6 min with the data already in memory. This answers "where should the database live". It is also the only option that removes the EFS read charges ([cost_bakta.md](cost_bakta.md)).
3. **Decide whether the sORF and pseudogene steps are needed.** The sORF step takes ~8 min (24 %) and finds 2–4 sORFs per genome. `--skip-sorf` would remove it. The pseudogene step takes ~3.6 min (11 %), almost all of it the second Diamond search, and finds 3–13 pseudogenes (`--skip-pseudo`). The circular plot takes 22 s (`--skip-plot`). These options change the output: sORFs appear as CDS in the GFF that Roary uses, so check this with whoever uses the results before switching anything off, and use the same setting for every sample in a comparison. The light database would remove the UPS/IPS lookups and the 46 GB scan, but it changes gene names and cross-references; use it only as a comparison point, not for production.
4. **Don't change `--threads` or vCPU yet.** At most ~10 of 16 vCPUs are used, and ~2.4 on average, but that is because Bakta is waiting on I/O. Measure the CPU again once the database is local, because the bottleneck may move to the CPU.
5. **EFS throughput limit: not a concern at this size.** Five jobs used 21 % of the file system's limit during Diamond. About 20–23 jobs in the Diamond stage at once would reach it.
6. **Instrument the next run:**
   * keep Bakta's `assembly.log` for every job (it gave every stage time here);
   * turn on detailed (1-minute) EC2 monitoring in the Batch launch template;
   * turn on the CloudWatch agent or Container Insights for memory;
   * save `aws batch describe-jobs` for every job (`createdAt`, `startedAt`, `stoppedAt`, attempts);
   * optionally set `PYTHONUNBUFFERED=1` in the wrapper so the CloudWatch log arrives line by line.
7. **Fix the wrapper** (second `bakta` call, unterminated here-document). Reported only; the code is not changed in this phase.
8. **Job size: pending.** The memory peak is needed before choosing the memory request (peak plus 20–30 % headroom) and the instance type. Size it with the page cache in mind: the ~47 GB of protein database kept in memory is what makes the pseudogene-candidate search fast. A smaller instance could lose it. Comparing instance types is out of scope here.
9. **Test 2–3 samples per instance**, one after another or together. They would share the ~47 GB already cached, so each extra sample might avoid most of its EFS read. That would save time and most of the EFS read charge ([cost_bakta.md](cost_bakta.md)). Measure time and EFS bytes per sample.
10. **Look at how the database is opened.** About one read is in flight during the UPS lookups, and the sORF lookups add one metadata operation each. Check the Bakta source in the image and test opening the database as read-only and immutable. Reported only; no code changes in this phase.

---

## 7. Pipeline view

* Bakta runs once per sample, in parallel, one job per instance. Roary waits for all samples, so **the slowest Bakta job (Sample_A1_S8, 35:50 container time, ended 11:03:58) and the last to end (Sample_BB_S7, 11:05:16) set when Roary can start.** End times bunch together (1:34 spread) because the jobs move in lockstep on the shared database (section 5).
* Bakta's share of the total time per sample, compared with SPAdes, Pilon and Roary: **TBD**.

---

## 8. Extra technical checks

| Check | Result in this run |
|---|---|
| I/O wait vs CPU time | **Measured (roughly).** About 80 vCPU-minutes of CPU per job against 33 min × 16 vCPU = 528 vCPU-minutes available, so ~15 % use. The work would take ~5 min on 16 vCPUs; the rest is waiting on EFS. The lookup stages (57 %) are almost pure I/O wait |
| Memory over time, process vs page cache | **TBD.** About 46.5 GB of database pages pass through the page cache per job, so container memory will include a large cache share |
| Cold vs warm database | All 5 jobs were cold on the instance, and the database was in IA. The lockstep pattern (section 5) suggests EFS serves data faster once another job has just read it. Needed: a warm run (second job on the same instance), a single job on its own, and a run with the database in Standard |
| Which stages use multiple threads | RNA stages ≈ 4–5 vCPU average; both Diamond searches ≈ 4–6 vCPU (even from memory); lookups behave as one read in flight. Finer detail needs 1-minute CPU and a thread dump (`py-spy dump`) during the lookups |
| Several jobs on one instance | Not tested. Worth testing: jobs on one instance would share the ~47 GB page cache. 5 jobs on separate instances already affect each other through the shared EFS |
| Input sensitivity (contigs, N50) | Some. The RNA stages were fastest on the least fragmented genome (Sample_BB_S7, 36 contigs). The large differences are in the EFS-bound stages, where how much a genome shares with the others seems to matter more than fragmentation |
| Edge cases (largest genome, smallest memory, timeouts) | Not tested |
| Reproducibility | Not testable (5 different genomes, 1 run each). The software versions were identical on all 5 jobs. Feature counts per genome are listed below for later comparison |
| Optional features (`--skip-*`) | **Measured:** sORF ~8 min (24 %) for 2–4 sORFs; pseudogenes ~3.6 min (11 %, almost all a Diamond search); circular plot 22 s (1 %). Nothing was skipped in this run |
| Startup overhead | Inside the container: 2 s download plus ~3 s Bakta start-up, ~0.3 % of the run. Image pull and queue **TBD** |
| Downstream effects | Output 93–94 MiB in 16 files per job, plus an 8.1–8.3 MiB GFF for Roary |
| EFS storage class | **Measured: 100 % IA** |
| EFS One Zone placement | **TBD.** Confirm the Batch subnets are in the file system's AZ |

### Annotation results (for reproducibility checks later)

| Sample | CDS | Hypothetical | Pseudogenes | tRNA | tmRNA | rRNA | ncRNA | ncRNA regions | CRISPR | sORF | oriC/V | CDS in GFF |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Sample_A1_S8 | 5,854 | 172 | 3 | 60 | 1 | 4 | 44 | 29 | 4 | 4 | 2 | 5,858 |
| Sample_A2_S1 | 5,883 | 172 | 4 | 60 | 1 | 4 | 44 | 29 | 4 | 4 | 2 | 5,887 |
| Sample_A3_S11 | 5,856 | 167 | 3 | 60 | 1 | 4 | 44 | 29 | 3 | 4 | 2 | 5,860 |
| Sample_A4_S8 | 5,819 | 167 | 5 | 60 | 1 | 4 | 44 | 29 | 3 | 4 | 2 | 5,823 |
| Sample_BB_S7 | 5,831 | 160 | 13 | 57 | 1 | 5 | 46 | 31 | 1 | 2 | 2 | 5,833 |

"CDS in GFF" = CDS + sORF, as the wrapper's check reports it.

---

## 9. Charts

The CloudWatch graph definitions (`*.bakta.json`) and screenshots (`*.png`) are in [`graphs/`](graphs): CPUUtilization, NetworkIn and the EFS graphs (data read, operations per second, average read size, throughput utilization, client connections). Still to make, from the data already collected except where noted:

1. **Stage breakdown:** horizontal bars per stage, median across the 5 jobs (section 2 table).
2. **Stacked bar per job:** wrapper / RNA stages / lookups / Diamond / pseudogenes / rest / upload.
3. **Timeline per job:** CPU % (5-minute points) and EFS read rate (1-minute) on one time axis, with stage boundaries from `assembly.log`.
4. **Gantt of the 5 jobs:** stage start and end per job, showing the lockstep at 10:49:01.
6. Memory over time (**needs the CloudWatch agent**).
7. EFS IA vs EFS Standard vs local disk, paired bars per stage (**needs the follow-up runs**).

---

## 10. Open questions and data still needed

1. ~~Sample_A1_S8 instance~~: answered (`i-04366523d15f5d0da`; files renamed to match).
2. ~~Bakta `assembly.log`~~: received and used for the stage times.
3. ~~Exact dependency versions~~: answered from `assembly.log`.
4. **Batch `describe-jobs`** for the 5 jobs: `createdAt`, `startedAt`, `stoppedAt`, attempts.
5. **Image tag and size** (ECR), and whether the AMI has the image cached (only Sample_BB_S7 shows a ~2 GB download at start).
6. **Memory:** is the CloudWatch agent or Container Insights available on the compute environment?
7. **Database file sizes:** `du -sh /mnt/efs/bakta_db/*`, to confirm that the 46.5 GB read during Diamond is `psc.dmnd` plus `pscc.dmnd`, the size of the SQLite file `bakta.db`, and what makes up the 203.6 GB on the file system.
8. **EFS AZ vs Batch subnets** (One Zone).
9. Are r5.4xlarge, 16 vCPU / 120 GiB and On-Demand still the settings used for this run?
10. **File system size:** the full database is about 64 GB ([tools/bakta README](../../../tools/bakta/README.md)), but the file system holds 203.6 GB. What are the other ~140 GB (an old archive, other versions)?
11. **NFS mount:** options from `/proc/mounts` (`rsize`, `nconnect`, amazon-efs-utils version), `read_ahead_kb`, and `/proc/self/mountstats` before and after each stage.
12. **Bakta source in the image** (`ups.py`, `cds.py`): how the lookups share the SQLite connection, and which database the pseudogene-candidate search reads.
13. **Diamond timings:** re-run the two Diamond searches by hand with `-v`, with the database on EFS and in memory, at 8 and 16 threads.

### Next profiling run, in priority order

1. One job alone on a fresh instance, then a second job on the same instance, to separate instance warm-up, EFS-side caching and the convoy effect.
2. Record the NFS layer on every job (item 11) and a thread dump during the UPS lookups.
3. Quick read tests on one instance: sequential reads of `psc.dmnd` and 4 KiB random reads of `bakta.db`, against a small copy in Standard, to test the latency explanations without moving the database.
4. Diamond with `-v` (item 13).
5. `du -sh /mnt/efs/bakta_db/*` (item 10).
6. Database on local disk (NVMe or gp3) at 8 and 16 threads, with 1-minute monitoring and memory.
7. 2–3 samples per instance: time and EFS bytes per sample.
8. A more varied panel (different sequence types, a larger genome).

## Data sources

| File | Content |
|---|---|
| `i-<instance-id>.assembly.log` (5 files) | Bakta's own log for each job |
| `i-<instance-id>.log-events.bakta` (5 files) | Job stdout from CloudWatch Logs (wrapper and Bakta) |
| `i-<instance-id>.ec2.stats.bakta.json` (5 files) | `aws cloudwatch get-metric-data`, namespace `AWS/EC2`, 10:26–11:10 UTC |
| `fs-05846c89e2da6b943.stats.bakta.json` | `aws cloudwatch get-metric-data`, namespace `AWS/EFS`, 10:26–11:10 UTC |

Instance IDs: `i-04366523d15f5d0da`, `i-072ae09e3f8a8a46a`, `i-082ba1ed032b65262`, `i-087b88d15d0f9ad60`, `i-0dde0a81430178b0b`.
