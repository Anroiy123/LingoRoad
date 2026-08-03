# Task 15: DQN Proof-of-Concept — RL path planning on a toy learner (TIME-BOXED: 4 days)

> Part of the QuestGraph plan. Read **Global Constraints** in `.claude/tasks/README.md` first.
> Depends on: task-8 (torch installed). Sprint 3.
> **Hard time box: 4 working days.** If the learning curve isn't clearly above the random
> baseline by then, stop, keep whatever plot exists, and write it up as future work
> (the brainstorm doc pre-authorizes this fallback). Not wired into the API — report artifact only.

**Files:**
- Create: `ml/questgraph_ml/rl/__init__.py`, `ml/questgraph_ml/rl/env.py`, `ml/questgraph_ml/rl/dqn.py`, `ml/tests/test_rl.py`, `ml/research/dqn_poc.py`

**Interfaces:**
- Consumes: torch.
- Produces: `ToyLearnerEnv(n_skills=5, seed)` — Gym-style `reset() -> state`, `step(action) -> (state, reward, done)`; `DQNAgent(state_dim, n_actions, seed)` with `act(state, eps)`, `remember(...)`, `train_step()`; artifacts `ml/reports/dqn_poc.png` + `ml/reports/dqn_poc.md`.

**MDP (mirrors the production formulation at toy scale):** state = mastery vector over 5 chained skills (skill *i* requires skill *i−1* at ≥ 0.5). Action = which skill to study. Practicing a skill whose prerequisite is met raises its mastery by `0.15·(1−mastery)`; otherwise by a wasted `0.01`. Every step, all skills decay by 0.005 (forgetting). Reward = increase in mean mastery. Episode ends when all skills ≥ 0.8 (bonus +1) or after 60 steps. Optimal play ≈ front-to-back with revisits — exactly what DQN should discover.

- [ ] **Step 1: Write failing tests**

`ml/tests/test_rl.py`:

```python
import numpy as np
from questgraph_ml.rl.env import ToyLearnerEnv
from questgraph_ml.rl.dqn import DQNAgent

def test_env_reset_and_step_shapes():
    env = ToyLearnerEnv(seed=0)
    s = env.reset()
    assert s.shape == (5,) and np.all((0 <= s) & (s <= 1))
    s2, r, done = env.step(0)
    assert s2.shape == (5,) and isinstance(done, bool)

def test_prerequisite_gating():
    env = ToyLearnerEnv(seed=0)
    env.reset()
    m_before = env.mastery.copy()
    env.step(4)                      # skill 4 blocked: skill 3 mastery starts low
    gain_blocked = env.mastery[4] - m_before[4]
    env.reset()
    m_before = env.mastery.copy()
    env.step(0)                      # skill 0 has no prerequisite
    gain_open = env.mastery[0] - m_before[0]
    assert gain_open > gain_blocked

def test_episode_terminates():
    env = ToyLearnerEnv(seed=0)
    env.reset()
    for _ in range(60):
        _, _, done = env.step(0)
        if done:
            break
    assert done

def test_agent_trains_without_error_and_buffer_fills():
    env, agent = ToyLearnerEnv(seed=1), DQNAgent(state_dim=5, n_actions=5, seed=1)
    s = env.reset()
    for _ in range(200):
        a = agent.act(s, eps=1.0)
        s2, r, done = env.step(a)
        agent.remember(s, a, r, s2, done)
        s = env.reset() if done else s2
    loss = agent.train_step()
    assert loss is not None and np.isfinite(loss)
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/test_rl.py -v` → FAIL.

- [ ] **Step 2: Implement env + agent, verify pass**

`ml/questgraph_ml/rl/env.py`:

```python
import numpy as np

class ToyLearnerEnv:
    """5 chained skills; see task file header for dynamics."""
    def __init__(self, n_skills: int = 5, seed: int = 0):
        self.n = n_skills
        self.rng = np.random.default_rng(seed)
        self.mastery = np.zeros(self.n)
        self.t = 0

    def reset(self) -> np.ndarray:
        self.mastery = self.rng.uniform(0.0, 0.2, self.n)
        self.t = 0
        return self.mastery.copy()

    def step(self, action: int):
        before = self.mastery.mean()
        prereq_ok = action == 0 or self.mastery[action - 1] >= 0.5
        gain = 0.15 * (1 - self.mastery[action]) if prereq_ok else 0.01
        self.mastery[action] = min(1.0, self.mastery[action] + gain)
        self.mastery = np.maximum(0.0, self.mastery - 0.005)   # forgetting
        self.t += 1
        goal = bool(np.all(self.mastery >= 0.8))
        reward = self.mastery.mean() - before + (1.0 if goal else 0.0)
        done = goal or self.t >= 60
        return self.mastery.copy(), float(reward), done
```

`ml/questgraph_ml/rl/dqn.py`:

```python
from collections import deque
import random
import numpy as np
import torch
import torch.nn as nn

class DQNAgent:
    def __init__(self, state_dim: int, n_actions: int, seed: int = 0,
                 lr: float = 1e-3, gamma: float = 0.98,
                 buffer_size: int = 10_000, batch: int = 64):
        torch.manual_seed(seed); random.seed(seed)
        self.n_actions, self.gamma, self.batch = n_actions, gamma, batch
        def net():
            return nn.Sequential(nn.Linear(state_dim, 64), nn.ReLU(),
                                 nn.Linear(64, 64), nn.ReLU(),
                                 nn.Linear(64, n_actions))
        self.q, self.target = net(), net()
        self.target.load_state_dict(self.q.state_dict())
        self.opt = torch.optim.Adam(self.q.parameters(), lr=lr)
        self.buffer = deque(maxlen=buffer_size)
        self.steps = 0

    def act(self, state, eps: float) -> int:
        if random.random() < eps:
            return random.randrange(self.n_actions)
        with torch.no_grad():
            return int(self.q(torch.as_tensor(state, dtype=torch.float32)).argmax())

    def remember(self, s, a, r, s2, done):
        self.buffer.append((s, a, r, s2, done))

    def train_step(self):
        if len(self.buffer) < self.batch:
            return None
        s, a, r, s2, d = map(np.array, zip(*random.sample(self.buffer, self.batch)))
        s = torch.as_tensor(s, dtype=torch.float32)
        s2 = torch.as_tensor(s2, dtype=torch.float32)
        r = torch.as_tensor(r, dtype=torch.float32)
        a = torch.as_tensor(a, dtype=torch.int64)
        d = torch.as_tensor(d, dtype=torch.float32)
        with torch.no_grad():
            target = r + self.gamma * (1 - d) * self.target(s2).max(1).values
        q = self.q(s).gather(1, a[:, None]).squeeze(1)
        loss = nn.functional.smooth_l1_loss(q, target)
        self.opt.zero_grad(); loss.backward(); self.opt.step()
        if (self.steps := self.steps + 1) % 200 == 0:
            self.target.load_state_dict(self.q.state_dict())
        return float(loss)
```

Run: `cd ml; .venv/Scripts/python -m pytest tests/ -v` → PASS.

- [ ] **Step 3: Training script with baselines**

`ml/research/dqn_poc.py`:

```python
"""DQN vs random vs fixed-order on ToyLearnerEnv -> ml/reports/dqn_poc.{png,md}"""
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from questgraph_ml.rl.env import ToyLearnerEnv
from questgraph_ml.rl.dqn import DQNAgent

ROOT = Path(__file__).parents[1]
EPISODES = 800

def run_policy(policy, episodes=100, seed=123):
    env = ToyLearnerEnv(seed=seed)
    returns = []
    for _ in range(episodes):
        s, total, done, t = env.reset(), 0.0, False, 0
        while not done:
            s, r, done = env.step(policy(s, t)); total += r; t += 1
        returns.append(total)
    return float(np.mean(returns))

def main():
    env, agent = ToyLearnerEnv(seed=0), DQNAgent(state_dim=5, n_actions=5, seed=0)
    curve = []
    for ep in range(EPISODES):
        eps = max(0.05, 1.0 - ep / 400)
        s, total, done = env.reset(), 0.0, False
        while not done:
            a = agent.act(s, eps)
            s2, r, done = env.step(a)
            agent.remember(s, a, r, s2, done)
            agent.train_step()
            s, total = s2, total + r
        curve.append(total)
        if ep % 100 == 0:
            print(f"ep {ep}: return {np.mean(curve[-100:]):.3f}")

    dqn_ret = run_policy(lambda s, t: agent.act(s, eps=0.0))
    rnd_ret = run_policy(lambda s, t: np.random.default_rng(t).integers(5))
    fix_ret = run_policy(lambda s, t: min(int(np.argmax(s < 0.8)), 4))

    out = ROOT / "reports"; out.mkdir(exist_ok=True)
    smooth = np.convolve(curve, np.ones(20) / 20, mode="valid")
    plt.figure(figsize=(7, 4))
    plt.plot(smooth, label="DQN (smoothed)")
    plt.axhline(rnd_ret, color="gray", ls=":", label=f"random {rnd_ret:.2f}")
    plt.axhline(fix_ret, color="tab:orange", ls="--", label=f"fixed-order {fix_ret:.2f}")
    plt.xlabel("episode"); plt.ylabel("return"); plt.legend()
    plt.title("DQN learning curve vs baselines")
    plt.tight_layout(); plt.savefig(out / "dqn_poc.png", dpi=150)

    (out / "dqn_poc.md").write_text(
        f"| Policy | Mean return (100 eps) |\n|---|---|\n"
        f"| DQN | {dqn_ret:.3f} |\n| Fixed order | {fix_ret:.3f} |\n"
        f"| Random | {rnd_ret:.3f} |\n", encoding="utf-8")
    print(f"DQN {dqn_ret:.3f} vs fixed {fix_ret:.3f} vs random {rnd_ret:.3f}")

if __name__ == "__main__":
    main()
```

Run: `$env:PYTHONPATH="ml"; ml/.venv/Scripts/python ml/research/dqn_poc.py` (minutes on CPU).
Expected: DQN clearly beats random; report honestly whether it beats the fixed-order heuristic (on a 5-skill chain a good heuristic is near-optimal — say so in the report; the point is the working MDP+DQN machinery).

- [ ] **Step 4: Commit**

```powershell
git add ml/
git commit -m "feat: DQN proof-of-concept for learning-path planning"
```
