# EST paper archive and EST I shared questions

**Completed:** 418 verified EST II questions; 327 shared EST I questions; 32 withheld
source issues. EST I bank total after import: 2,903; EST II: 1,545.

All ten PDFs, 450 original question images, solutions, review records, SQL and
preparation scripts are preserved in the checksum-verified archive under `archive/`.
It is split into 41 binary parts for the connected GitHub upload size limit.
The source data is complete; no credentials are included.

Clone/download the repository, then use Python 3.12 or later:

```sh
python content-releases/2026-09-26-est-papers/restore.py
```

This restores the complete 551-file release in this directory. Then open
`report.html` for the offline instructor report. The detailed release README
inside the archive documents reconstruction and verification.

Archive SHA-256: `7d802ebd21ac651d9a9d409e7f3f7b1dd2e9509349ad982580305ebe634dbf72`

The EST I mapping, inventory and sharing/verification SQL are also directly
browsable in this folder. The student portal uses embedded source images from
Supabase and does not require the repository archive to be unpacked for use.

The later school-sample prompt repair is recorded separately in
`../2026-09-26-may-sample-context.sql`.
