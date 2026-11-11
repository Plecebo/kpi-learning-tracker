# KPI Development & Measuring Change Over Time — 3-Month Learning Roadmap

Grounded in the framework research (`kpi-development-frameworks.md`).

**Goal (from the root request):** become able to (1) develop KPIs that trace to a real goal, and
(2) measure whether a change actually had impact over time — not just produce numbers that look busy.

---

## How the four researched frameworks fit together

| Framework | What it does | Use it when |
|---|---|---|
| **SMART** (Doran 1981) | Quality-checks a *single* KPI/objective | Writing or auditing any one metric; the final editing pass on everything |
| **Balanced Scorecard** (Kaplan & Norton 1992) | Translates strategy into a *balanced* KPI set across 4 perspectives | You need a standing dashboard of organizational health, not one goal |
| **OKR** (Grove → Doerr) | Steers *change*: a few ambitious quarterly goals + measurable key results | You're driving a specific change and need a focused cadence |
| **GQM** (Basili et al. 1994) | Derives metrics so *every metric traces to a goal* | Any time you fear you're measuring the wrong thing |

Plus adjacent topics the research flagged as uncovered, folded in here: **North Star metric**,
**Performance Prism**, **Four Disciplines of Execution (4DX)**.

**The through-line:** SMART is the grammar, GQM is the logic, BSC is the map, OKR is the engine,
North Star is the compass. You don't pick one — you use the right one for the job.

---

## The 3-month arc

- **Month 1 — Framework literacy & writing good metrics** (Weeks 1–4)
- **Month 2 — Deriving metrics from goals & designing measurement** (Weeks 5–8)
- **Month 3 — Measuring change over time & communicating it** (Weeks 9–12)

Each week: a reading block (~2–4 h), a practice exercise (~1–3 h, done on *real* estate data, not
toy examples), and one "check-in" artifact that feeds the accountability system.

---

## Month 1 — Framework literacy & writing good metrics

### Week 1 — Why measure; leading vs lagging; vanity vs actionable
- **Read:** Doran (1981) SMART paper; Eric Ries on "vanity metrics"; *Lean Analytics* (Croll &
  Yoskovitz), ch. 1–2.
- **Practice:** list 5 metrics you already track (estate uptime, backup success rate, wiki coverage,
  job-applications sent, PVE host load). For each, label **leading vs lagging** and
  **actionable vs vanity**. Rewrite every vanity one as actionable.
- **Check-in artifact:** a one-page table of your 5 metrics with labels + 3 rewrites.

### Week 2 — SMART deep-dive
- **Read:** Doran's full PDF. Note his original wording ("**Assignable**", "**Realistic**") vs the
  modern "**Achievable/Relevant**". Pick one version and state it. (The research flagged this
  variance — don't skip it.)
- **Practice:** write 10 SMART KPIs for real estate things (e.g. "Proxmox host CPU stays under X
  p95 for 30 days"; "backup job succeeds on first run Y% of the time each month"). Run the
  5-criteria check on each and fix the failures.
- **Check-in artifact:** 10 KPIs with a pass/fail note per criterion.

### Week 3 — Balanced Scorecard
- **Read:** Kaplan & Norton, "The Balanced Scorecard — Measures that Drive Performance" (HBR 1992);
  *The Balanced Scorecard* (1996) chapters on the four perspectives; HBS Online explainer.
- **Practice:** build a 4-perspective scorecard for a small org you know well — the lab itself.
  Financial → Customer → Internal process → Learning & growth; 2–3 measures per perspective.
- **Check-in artifact:** the draft scorecard (12 measures max).

### Week 4 — OKR
- **Read:** *Measure What Matters* (Doerr), Part 1; whatmatters.com OKR FAQ.
- **Practice:** draft one quarterly Objective + 3 Key Results for a real change (e.g. "reduce mean
  time to resolve estate incidents"). Verify each KR is **measurable and verifiable**, aggressive
  yet realistic.
- **Check-in artifact:** 1 objective + 3 KRs with a measurable-verifiable self-check.

---

## Month 2 — Deriving metrics from goals & designing measurement

### Week 5 — GQM (Goal → Question → Metric)
- **Read:** Basili, Caldiera, Rombach (1994) GQM; the UMD handout.
- **Practice:** take one goal and run the full trace — goal (purpose/object/issue/viewpoint) →
  questions → metrics. Reproduce the paper's "timeliness of change request processing" example on a
  real estate workflow (e.g. how fast do Gitea PRs get reviewed/merged?).
- **Check-in artifact:** one complete GQM trace, goal→questions→metrics, on real data.

### Week 6 — North Star + the uncovered frameworks
- **Read:** Amplitude's *North Star Playbook*; a Lenny Rachitsky piece on choosing a North Star; a
  *summary* of *The Four Disciplines of Execution* (McChesney, Covey, Huling) — the four disciplines
  fit on one page, don't read the whole book here. (Performance Prism is deferred to Week 12's
  gap-fill.)
- **Practice:** propose a single North Star metric for a project, then list 3 **counter/guardrail
  metrics** that would catch it being gamed (e.g. if North Star = "PRs merged", guardrail = "revert
  rate").
- **Check-in artifact:** 1 North Star + 3 guardrails, with a one-line rationale each.

### Week 7 — Measurement design & instrumentation
- **Read:** *How to Measure Anything* (Hubbard) — the "how to define the measurement" and
  calibration chapters.
- **Practice:** for one KPI, write its full **operational definition**: formula, data source, pull
  frequency, owner, target, and floor/ceiling. Then state *where the data actually comes from*
  (log line? API? manual?) and how you'd instrument it if it doesn't exist yet.
- **Check-in artifact:** one operational-definition card for a single KPI.

### Week 8 — Statistical thinking: variation & signals
- **Read:** Donald Wheeler, *Understanding Variation* (intro) — the "four questions" and the
  signal-vs-noise distinction; a control-chart primer.
- **Practice:** plot a metric you have history for (PVE host load, backup duration, job-search
  response time). Compute a moving average + rough control limits. Decide: is the latest movement a
  real signal or noise?
- **Check-in artifact:** one chart with your signal/noise verdict and why.

---

## Month 3 — Measuring change over time & communicating it

### Week 9 — Before/after & causal thinking
- **Read:** *Practical Statistics for Data Scientists* (Bruce & Bruce) experiment chapter; a good
  counterfactual/before-after article.
- **Practice:** take a recent change you actually made (a PR, a config change, a routing rule).
  Frame it rigorously: what's the baseline? What *would have happened without it*? List the
  confounders. Run a simple before/after comparison.
- **Check-in artifact:** one before/after write-up with baseline, comparison, and confounders.

### Week 10 — Dashboards & communication
- **Read:** Stephen Few, *Show Me the Numbers*; a data-storytelling piece (e.g. on "state of the
  metric" reviews).
- **Practice:** build one Grafana dashboard (already in the lab) for a KPI set, then write a
  one-page "state of the metric" narrative a non-specialist could act on.
- **Check-in artifact:** a dashboard link + the one-page narrative.

### Week 11 — Capstone (apply the whole stack)
- **Practice:** one end-to-end pass on a real thing — pick a goal → choose the right framework →
  write the KPIs → write operational definitions → collect a baseline → (optionally) make the change
  → measure before/after → write it up.
- **Check-in artifact:** the capstone write-up (this is the portfolio piece).

### Week 12 — Consolidate, gap-fill, present
- **Practice:** re-read the framework report; close the gaps you skipped (Performance Prism, 4DX in
  depth, anything else skipped along the way). Write a short "what I learned and what I'd apply to
  the lab" note.
- **Check-in artifact:** the consolidation note + a 5-minute self-presentation.

---

## Resource list

### Books (primary)
- *Measure What Matters* — John Doerr (OKR)
- *Lean Analytics* — Croll & Yoskovitz (metric literacy, vanity-vs-actionable)
- *How to Measure Anything* — Douglas Hubbard (measurement design, calibration)
- *The Balanced Scorecard* (1996) + *Strategy Maps* (2004) — Kaplan & Norton
- *The Four Disciplines of Execution* — McChesney, Covey, Huling
- *Understanding Variation* — Donald Wheeler (optional, statistical thinking)
- *Show Me the Numbers* — Stephen Few (optional, communication)

### Courses
- HBS Online — "Balanced Scorecard" (paid)
- Amplitude Academy (free; product/North Star metrics)
- Any OKR course built on *Measure What Matters* (Coursera/Udemy)
- whatmatters.com OKR guide (free) — prefer this over the retired Google re:Work guide

### Articles / papers (verified in the research report)
- Doran (1981), "There's a S.M.A.R.T. way to write management's goals and objectives", *Management Review* 70(11)
- Kaplan & Norton (1992), "The Balanced Scorecard — Measures that Drive Performance", *HBR*
- Basili, Caldiera, Rombach (1994), "The Goal Question Metric Approach"
- whatmatters.com OKR FAQ
- Amplitude, *North Star Playbook*

> Note: course links/names and any paywalled titles should be re-confirmed before purchase —
> names change and HBR is paywalled. The four papers above are the verified anchors; everything
> else is recommended reading, not yet fact-checked.

### Practice environment
The practice ground is a small self-hosted lab. Real data to work with, already instrumented: PVE host/container metrics,
backup success & duration, Gitea PR review/merge latency, wiki coverage, a job-application pipeline,
Bifrost routing. No toy datasets needed.

---

## How this feeds the accountability system

The sibling task (`t_8f6c5adc`) designs weekly check-ins and mastery self-assessment. This roadmap
supplies the **12 weekly milestones** those check-ins track, and each week above names a concrete
**check-in artifact** the tracker can grade. Keep the two in lockstep — the roadmap is the "what",
the tracker is the "did you actually do it and did you get better".

---

## Open questions for Larry (answers shape the plan, no blocking)

1. **Time budget** — is 5–8 h/week realistic? That's the pace assumed here.
2. **Domain for practice** — estate ops, a job-application pipeline, or a work context? (I assumed
   lab-first since it's already instrumented.)
3. **Depth vs breadth** — do you want working fluency across all four frameworks, or one framework
   mastered end-to-end (OKR + measurement) with the rest at the awareness level?
