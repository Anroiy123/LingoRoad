# DQN PoC checkpoint selection — design

Date: 2026-07-19
Status: approved (user), this session
Context: direct continuation of
`docs/superpowers/specs/2026-07-18-dqn-extended-training-design.md`. Both
4000-episode runs failed the ≥ 0.581 gate (0.559 schedule-unchanged, 0.449
slow-decay) while the training curve sat at 0.60–0.63 mid-run — the final
network is not the best network. This spec adds checkpoint selection so the
best network is what gets evaluated.

## Goal

Retry the 4000-episode run with periodic validation-based checkpoint selection;
if the selected network's test-eval mean return ≥ 0.581, it becomes the headline
PoC result everywhere (same replacement scope as the 2026-07-18 spec).

## Decisions (user-approved)

1. **Selection method**: every `CHECKPOINT_EVERY = 100` training episodes (and
   once after the final episode), evaluate the current network greedily
   (ε = 0) for 20 episodes on a **validation** env `ToyLearnerEnv(seed=42)`.
   When mean validation return improves on the best so far, snapshot
   `copy.deepcopy(agent.q.state_dict())`. After training, load the best
   snapshot back into the agent and record which episode it came from.
   Selection never touches the test seed 123 — no selection on the test set.
2. **Training config**: `EPISODES = 4000`, ε decay over 400 then floor 0.05
   (the original schedule — the run whose mid-training networks looked good).
   `DQNAgent` (library class) stays untouched; selection lives in the research
   script's `train_dqn()`, which gains `episodes` / `checkpoint_every`
   parameters defaulting to the module constants (for testability).
3. **Gate**: unchanged — test-eval (100 episodes, seed 123) mean return
   ≥ 0.581 replaces the published result; otherwise nothing published changes
   and the negative finding goes to the ledger. No further fallback this time:
   one run, one verdict.
4. **Transparency**: the generated report's protocol paragraph states the
   selection method (cadence, 20-episode greedy validation on seed 42, test on
   seed 123) and the selected episode. The §7/A.7 protocol prose in
   `docs/learning-path-optimization.md` and `docs/bao-cao-mang-3-vn.md` gains
   the same one-sentence description when the gate passes.
5. **Cost accounting**: selection evals run inside the training wall-clock, so
   the reported DQN offline cost includes them (~+4s expected: 41 evals × 20
   episodes × 60 steps of forward passes).

## Change surface

- `ml/research/dqn_poc.py` — `CHECKPOINT_EVERY` constant; `train_dqn(episodes,
  checkpoint_every)` checkpoint loop returning `(agent, curve, best_ep)`;
  `report_lines()` protocol text + selected-episode note; `main()` passes the
  new return value through.
- `ml/tests/test_dqn_poc_report.py` or new `ml/tests/test_dqn_checkpoint.py` —
  deterministic test that the returned agent reproduces the best validation
  score (proves "keep best" kept the best).
- On gate pass only (same list as the 2026-07-18 spec):
  `ml/reports/dqn_poc.{md,png}`, `docs/learning-path-optimization.md` (§6.1
  table + finding 2 + §7 prose), `docs/bao-cao-mang-3-vn.md` (A.6.1 + A.7
  mirrors), `ml/reports/EVIDENCE.md` row 7.
- `src/backend/.superpowers/sdd/progress.md` — session ledger entry either way.

## Verification

- New checkpoint test + existing 46 tests green.
- Experiment run completes (~8.5 min); DP/greedy/random rows must reproduce
  0.636 / 0.533 / 0.197 exactly (identical seeds).
- If replacing: stale-number grep (`0.581`, `+9%`, `800 episodes`, `800
  training`) hits only historical records under `docs/superpowers/` and the
  ledger.

## Out of scope

- Hyperparameter tuning, multi-seed runs, environment changes (unchanged from
  the 2026-07-18 spec).
- Early stopping (rejected: yesterday's curve recovered after dips — selection
  subsumes it).
