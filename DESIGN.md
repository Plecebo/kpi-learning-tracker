# KPI Learning — Accountability System Design

Companion to `docs/kpi-learning-roadmap.md` (the "what"). This doc is the "did you
actually do it, and did you get better" layer. The system is deliberately dogfooded: the learning
plan about KPIs is itself tracked with GQM, an operational definition, and a signal-vs-noise
verdict — so every week of the plan also practices the framework on itself.

---

## 1. The GQM trace for the learning goal itself

- **Goal:** improve Larry's ability to (a) develop KPIs that trace to a real goal and (b) measure
  whether a change had impact over time. Purpose: capability. Object: Larry's measurement practice.
  Issue: competence. Viewpoint: Larry (self) + work output.
- **Q1 — Am I doing the work?** → `M1 weekly completion` (weeks completed on schedule / weeks elapsed)
- **Q2 — Is the output good, not just present?** → `M2 artifact quality score` (rubric grade per check-in artifact)
- **Q3 — Is it sticking?** → `M3 retention score` (spaced re-test pass rate, weeks 4/8/12)
- **Q4 — Can I apply it to a real thing?** → `M4 application score` (capstone + one applied change scored by rubric)
- **Q5 — Is the pace sustainable?** → `M5 hours per week` (self-reported, vs the 5–8 h assumption)

Every metric below is an operational definition of one of these questions. If a weekly check-in
can't fill a metric, that failure *is* the check-in's finding.

## 2. Where the files live

```
kpi-learning-tracker/        # the repository root — everything the plan needs is in here
├── README.md            # index: which doc does what
├── docs/                # the "what": kpi-learning-roadmap.md + kpi-development-frameworks.md
├── ledger.md            # one row per week — the single source of progress truth
├── rubric.md            # the 0–3 self-assessment rubric (same scale all 12 weeks)
├── checkin-template.md  # copy per week: weeks/week-01.md .. week-12.md
├── weeks/               # filled check-ins + artifacts live here (or link out)
├── mastery-tests.md     # the week 4/8/12 re-tests and the capstone scoring sheet
└── lab/                 # the practice environment (venv, DuckDB, Jupyter, data snapshots)
                         #   lab/README.md = quickstart, lab/docs/EXERCISES.md = week -> query
```

This directory is plain files so it survives profile changes and is readable in any editor.
Hand-off proposal to the wiki/librarian happens only at week 12 (consolidation week), so the
tracker stays lightweight while the plan is live.

## 3. Weekly check-in (the cadence)

- **When:** Sunday evening, 15–30 minutes. A Hermes cron (`kpi-weekly-checkin`) posts the prompt
  into the default profile's Bot Chat on Sundays at 19:00 so the check-in has a heartbeat and
  can't be silently skipped.
- **What:** copy `checkin-template.md` into `weeks/week-NN.md`, fill it, add one row to `ledger.md`.
- **The five questions in the template:**
  1. Did the week's reading happen? (yes / partial / no + what got in the way)
  2. Is the week's check-in artifact done, and where is it? (path or link)
  3. Self-assess the artifact against `rubric.md` (0–3, with one sentence of justification)
  4. Hours spent this week (reading / practice separately)
  5. One thing you'd now do differently when writing a metric — this is the journal line that
     makes week 12's consolidation note trivial to write.
- **Miss rule:** a missed week is recorded as `missed` in the ledger, not skipped. Two consecutive
  misses trigger a scope decision (drop to the every-other-week pace, or cut a framework to
  awareness level) rather than silent catch-up debt. That's a decision for Larry, made once, not
  a guilt loop made weekly.

## 4. Self-assessment metrics (rubric, 0–3 per artifact)

Same scale every week so scores are comparable over time:

| Score | Meaning (behavioral anchors, not vibes) |
|---|---|
| **0 — absent** | Artifact not produced |
| **1 — present** | Artifact exists but is generic; could have been written without doing the reading |
| **2 — applied** | Uses the week's framework correctly on real estate data; concrete numbers/names |
| **3 — critiqued** | Applied *and* self-critiqued: names a weakness in own artifact, a way the metric could be gamed, or a counter-metric |

Rationale: a 0–3 anchor scale is cheap to score weekly, resists grade inflation better than 1–10,
and the "critique your own artifact" anchor at 3 is itself practice for Weeks 6 and 9.

## 5. Ledger schema (`ledger.md`)

One row per week:

```
| Week | Done (Y/partial/missed) | Rubric 0–3 | Hours (read/prac) | Leading signal | Note |
```

- **Rubric 0–3** = this week's artifact score.
- **Leading signal** = one forward-looking fact ("week 3 book not started", "capstone topic chosen").
  The completion column is lagging; this column is the leading indicator so trouble is visible
  *before* the week is lost — the same leading/lagging distinction Week 1 teaches, applied to the
  tracker itself.

## 6. Measuring mastery (weeks 4, 8, 12 gates)

Mastery is not measured by "read the book." Three gates, each with a written test:

- **Week 4 gate — framework literacy:** without notes, write one SMART objective, one OKR set
  (O + 3 KRs), and one 4-perspective scorecard for a named org, then grade yourself against the
  rubric. Pass at ≥ 2 average across the three pieces. Failure → redo the artifact, not the week.
- **Week 8 gate — derivation & measurement:** given a fresh goal (unseen before), produce a GQM
  trace, one operational definition, and a signal-vs-noise verdict on a plotted series. Pass at ≥ 2
  average. This is a transfer test: new goal, not the practice one.
- **Week 12 gate — capstone + retention:** the capstone write-up scored on the rubric (target ≥ 2,
  with at least one 3), plus a 10-question mixed self-quiz assembled from the weekly "one thing
  I'd do differently" journal lines. Pass → the plan is complete; the consolidation note goes to
  the librarian for the wiki.

**Retention (spaced):** each gate re-tests the previous gates' skills in one question, so weeks 8
and 12 double as spaced retrieval — the cheapest known defense against read-and-forget.

## 7. Cron mechanics

- Job name `kpi-weekly-checkin`, schedule Sunday 19:00, `--no-agent --script kpi-weekly-checkin.sh
  --deliver bot-chat` on the default profile. The script prints the check-in prompt and points at
  the template; it prints nothing when the plan is complete (weeks/week-12.md exists → silent).
- The cron is a nudge, not the record. The record is `ledger.md`. If the cron dies, the system
  still works; if the ledger stops growing, the system has stopped regardless of what the cron says.

## 8. What this system deliberately does NOT do

- No dashboards or Grafana for a 12-week personal plan — the ledger is the dashboard.
- No agent-side grading of artifacts: the rubric is self-scored on purpose (calibration is part of
  the skill). An external review exists once, at the week 12 capstone, via the librarian review card.
- No streak mechanics. Two misses trigger one scope decision; three+ means the plan's time-budget
  assumption (open question 1 for Larry) was wrong and the plan itself gets revised.
