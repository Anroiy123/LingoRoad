# Design: Task 15 — DQN PoC + four-policy comparison on ToyLearnerEnv

Date: 2026-07-17
Status: approved (design presented and accepted in session)
Sources: `src/backend/.claude/tasks/task-15-dqn-poc.md` (predates the QuestGraph→LingoRoad
rename; paths adapted), `docs/learning-path-optimization.md` §7 (experiment protocol).

## Goal

Prove the MDP + DQN machinery works on a toy learner environment, and put measured
numbers behind the Greedy vs DP vs RL comparison in `docs/learning-path-optimization.md`
§6. Report artifact only — nothing is wired into the API.

## Non-goals

- PPO, action masking, the 156-skill production graph (future work per doc §8).
- Multiple-seed studies or confidence intervals (single eval protocol per §7).
- Any .NET changes.

## Components (all under `src/backend/ml/`)

### `lingoroad_ml/rl/env.py` — ToyLearnerEnv
Per the task-15 file, verbatim dynamics: n = 5 chained skills (skill *i* requires
skill *i−1* ≥ 0.5); practicing an unlocked skill gains `0.15·(1−m)`, a blocked one 0.01;
all skills decay 0.005/step (floored at 0); reward = change in mean mastery, +1 bonus
when all ≥ 0.8 (goal, episode ends); cap 60 steps. `reset()` draws mastery
~ U(0, 0.2); transitions are otherwise deterministic. Gym-style
`reset() -> state`, `step(action) -> (state, reward, done)`.

### `lingoroad_ml/rl/dqn.py` — DQNAgent
Per the task-15 file: MLP 64-64-ReLU, Adam lr 1e-3, γ = 0.98, replay buffer 10k,
batch 64, target network synced every 200 train steps, smooth-L1 loss, ε-greedy
`act(state, eps)`. CPU is sufficient at this scale.

### `lingoroad_ml/rl/dp.py` — value iteration (the theory anchor)
Per doc §7: k = 11 mastery levels per skill (0.0, 0.1, …, 1.0) → 11⁵ = 161,051 states.

> **Amendment (found during implementation, 2026-07-17):** §7's "nearest-grid
> rounding" is degenerate at k = 11 — practice gains near high mastery are smaller
> than half a grid cell (0.7 → 0.74 rounds back to 0.7), so the goal is unreachable
> in the rounded model and no tabular transition ever carries the +1 bonus; DP
> collapsed below greedy. Fixed two ways: (1) successors are represented by
> multilinear interpolation over their 2⁵ neighbouring grid points (Kushner–Dupuis
> Markov-chain approximation), which preserves the expected successor exactly;
> (2) the goal bonus is attached to arrival in the goal set — terminal grid states
> hold V = 1.0, and true one-step goal transitions (possible at other k) keep the
> bonus in their reward with zero continuation, so it is never double-counted.
> `docs/learning-path-optimization.md` §7 is updated to match in the doc task.

- **Dynamics identity by construction:** the transition table is built by calling the
  real `ToyLearnerEnv.step()` on each grid state (set `env.mastery` to the grid point,
  step, round the successor to the nearest grid point) — never a re-implemented copy of
  the dynamics. Yields `next_state[s, a]` (int index) and `reward[s, a]` arrays.
- Goal states (all levels ≥ 0.8) are absorbing: V = 0, no outgoing transitions; the
  +1 bonus is captured in the reward of the transition that enters them.
- Value iteration, fully vectorized over the precomputed arrays, γ = 0.98, until
  ‖V_{k+1} − V_k‖∞ < 1e-6. Expected wall-clock: seconds.
- `DpPolicy`: round the live (continuous) state to the grid, act
  `argmax_a reward[s, a] + γ·V[next_state[s, a]]`.
- Known approximation, stated honestly in the report: infinite-horizon VI ignores the
  60-step cap, and grid rounding introduces discretization error.

### `research/dqn_poc.py` — experiment script
1. Train DQN: 800 episodes, ε decays 1.0 → 0.05 over 400 episodes, train on every step;
   record per-episode return (learning curve) and total training wall-clock.
2. Solve DP (record solve wall-clock).
3. Evaluate four policies through **one shared evaluator** (identical dynamics, 100
   episodes, env seed 123 per §7): random (uniform), greedy (first skill with mastery
   < 0.8, front to back), DP, DQN (ε = 0). Collect per episode: return, length, goal
   flag; and mean per-decision latency (`perf_counter` around the policy call; DQN under
   `torch.no_grad()`).
4. Write outputs (below).

Run as a module from `ml/` (`python -m research.dqn_poc`) — plain path invocation
cannot import `lingoroad_ml` (established convention from task 12).

## Outputs

- `ml/reports/dqn_poc.png` — DQN learning curve (20-episode moving average) with
  random and greedy baselines as horizontal lines.
- `ml/reports/dqn_poc.md` — table: policy × {mean return, mean episode length
  (censored at 60), goal-reach rate, offline cost (s), per-decision latency (ms)};
  expected ordering DP ≥ DQN ≥ greedy > random; honest notes: greedy is near-optimal
  on a 5-skill chain (say so), DP discretization/horizon caveats, whether DQN beat
  greedy or not — report whatever the numbers say.
- `docs/learning-path-optimization.md` — §6 gains a companion "measured on
  ToyLearnerEnv (task 15)" table with the same rows; §7 gains a short results note
  pointing at `src/backend/ml/reports/dqn_poc.md`. Keep the EN-with-VN-key-terms
  convention.

## Testing (TDD; tests first, red → green)

`ml/tests/test_rl.py`:
1. Env: reset/step shapes and bounds (task file).
2. Env: prerequisite gating — gain on unlocked skill > gain on blocked skill (task file).
3. Env: episode terminates within the cap (task file).
4. DQN: 200 exploration steps fill the buffer; `train_step()` returns a finite loss
   (task file).
5. DP: transition builder agrees with a direct `env.step()` call on sampled grid states
   (dynamics identity).
6. DP: value iteration converges (returns, finite V, tolerance met).
7. DP: policy reaches the goal within 60 steps from seeded resets.
8. DP: mean return ≥ greedy mean return − 0.05 on a small shared-seed eval batch
   (theoretical ordering, with headroom for grid discretization error).

Full ml suite must stay green (24 existing tests). .NET untouched.

## Risks & time box

- **Hard time box: 4 working days** (task file). If the DQN curve is not clearly above
  random by then: stop, keep the plot, write it up as future work — fallback
  pre-authorized by the task file.
- DQN beating greedy is *not* required for success; the point is working machinery and
  an honest measured comparison.
- DP state space (161,051 × 5) is small enough for dense numpy; if the table build via
  `env.step()` per state-action is slow in pure Python (~800k calls), batch it with a
  vectorized variant of the same formula *validated against* `env.step()` by test 5.

## Commits

Explicit paths only (never `git add -A`); never commit `ml/data/`, `ml/checkpoints/`,
`.claude/`. Reports (`ml/reports/dqn_poc.*`) are committed — task-7 precedent.
Sequence: spec (this file) → plan → implementation commit(s) per the plan.
