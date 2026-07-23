# Presentation Talking Points — Intelligent Automation Pipeline

> Glance-at cheat-sheet, not a script. MMM is the centerpiece; debugging is a short aside.
> Spoken register — say it in your own words.

## 1. Frame it: where my piece sits

- "There's an upstream decision engine — the **WHEN Layer** (rebuilt as RE:AI). Its job is to decide *who* to act on and *when* — it watches priority accounts for a structural trigger, runs three gates (Priority → Trigger → Stage), and emits a one-page action brief."
- "My pipeline picks up from there. The engine says *who and when*; my system does **validate → activate → measure → learn**. And the part I want to focus on is the *learn* — figuring out *which channel* actually works."
- "So together it's a closed loop: engine decides, my pipeline acts and measures, and the outcomes feed back to the engine."

## 2. The pipeline in one line

- "A brief comes in, gets scored, an AI drafts the outreach, a human approves in seconds, and it fans out into a tracked campaign. Real outcomes get measured from the tools the world uses — Google Analytics, Calendly, Gmail, Salesforce — and an adaptive engine decides whether to keep going, pause, or escalate."

## 3. MMM — the centerpiece

**The question**
- "Once outcomes are measured, the interesting question is: *which channels actually move the needle* — email, LinkedIn, phone, ads? So we fit a model: per funnel stage, regress 'did we hit the objective' on the mix of channels used."

**The trap**
- "But reps and the AI don't pick channels randomly — they lavish the good channels on accounts that already look promising. So the data is confounded. A channel can look like a star just because it got used on accounts that were going to convert anyway."
- "That makes the naive model *correlational, not causal*. Act on it and you can point reps at the wrong channel with full confidence."

**What I built — the capstone**
- "So I built a channel-exploration layer. For a small fraction of touches, the system *ignores* the recommended channel and picks one at random — a proper randomized arm."
- "That randomization breaks the confounding. Fit the model on just the explore data and the estimate becomes *causal* — a real experiment, not just an observation."
- "And I proved it with a simulation — two synthetic worlds, one confounded, one with the exploration arm. On the confounded data the model confidently calls a channel that does *nothing* a top performer. The exploration arm correctly clears it. That's the whole argument in one picture."
- "It's built end-to-end: the randomization hook in the pipeline, a config switch to turn it on and dial the rate, the causal analysis mode in the model, and a dashboard readout comparing explore vs. exploit."

**Honest caveat**
- "We're pre-traffic, so this is proven in simulation and *ready* for real data rather than run on it. The moment real traffic flows, the model starts learning causally instead of just correlating."

## 4. Debugging — brief aside

- "Quick reliability note: while doing this I ran a health check and caught that the whole pipeline had gone silent — the automation platform had hit its monthly execution limit, so nothing was running. I traced it, cut the wasted runs, and got it back."
- "I also found the dashboards were pointed at an old database after a migration, with a missing table — fixed those and made the setup script complete so a fresh deploy can't hit the same gap."
- "Point being: it's not just built, it's diagnosable and maintainable."

## 5. Close

- "So the headline: the pipeline doesn't just *act* — it closes the loop back to the engine, and it's set up to learn *causally* which channels work. That's the piece I'd hand off as the most reusable."

---
### If asked
- **"Is the loop live?"** — "The pipeline side is built; turning the feedback on needs the engine's feedback endpoint and the n8n quota cleared. It's a one-config-line flip once those land."
- **"Is the MMM running on real numbers?"** — "Not yet — pre-traffic. It's proven on a simulation with known ground truth, and wired to run the moment data exists."
