import numpy as np

from lingoroad_ml.rl.dqn import DQNAgent
from lingoroad_ml.rl.env import ToyLearnerEnv


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
    env.step(4)                      # skill 4 blocked: skill 3 mastery starts < 0.5
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
