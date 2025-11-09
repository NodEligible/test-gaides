cd /root/rl-swarm && cp hivemind_exp/dht_utils.py hivemind_exp/dht_utils.py.bak && cat > hivemind_exp/dht_utils.py <<'EOF'
import hashlib
import logging
from functools import lru_cache
from typing import Any
from hivemind.dht import DHT
from hivemind.utils import ValueWithExpiration
from hivemind.p2p.p2p_daemon import P2PDaemonError
from hivemind_exp.hivemind_utils import HivemindNode

logger = logging.getLogger("rlswarm.hivemind")

ROUND_STAGE_NUMBER_KEY = "rl_swarm_rs"
LEADERBOARD_KEY_PREFIX = "rl_swarm_leaderboard"
REWARDS_KEY = "rl_swarm_rewards"
OUTPUTS_KEY_PREFIX = "rl_swarm_outputs"

def leaderboard_key(round_num, stage) -> str:
    return f"{LEADERBOARD_KEY_PREFIX}_{round_num}_{stage}"

def rewards_key(round_num, stage) -> str:
    return f"{REWARDS_KEY}_{round_num}_{stage}"

def outputs_key(node_key: str, round_num, stage) -> str:
    return f"{OUTPUTS_KEY_PREFIX}_{node_key}_{round_num}_{stage}"

def node_outputs_key(node: HivemindNode) -> str:
    return outputs_key(node.key, node.round_num, node.stage_num)

def hash_keys(outputs):
    result = {}
    for k, v in outputs.items():
        if len(k) != 32:
            k = hashlib.md5(k.encode()).hexdigest()
        result[k] = v
    return result

@lru_cache
def get_outputs(dht: DHT, node_key: str, r, s, get_cached_fn=None) -> dict[str, tuple[float, dict]]:
    if get_cached_fn:
        if outputs := get_cached_fn(r, s):
            return hash_keys(outputs)
    if outputs := get_dht_value(dht, key=outputs_key(node_key, r, s), latest=False):
        return hash_keys(outputs)
    raise ValueError(f"could not retrieve stage outputs for {node_key} at round {r} stage {s}")

def get_round_and_stage(dht: DHT) -> tuple[int, int]:
    value = get_dht_value(dht, key=ROUND_STAGE_NUMBER_KEY, latest=True)
    if not value:
        raise ValueError("cannot find current round and stage")
    round_num, stage = value
    return round_num, stage

# === Safe DHT interaction ===

def _unwrap_value(wrapper):
    if not wrapper:
        return None
    assert isinstance(wrapper, ValueWithExpiration)
    value = wrapper.value
    if isinstance(value, dict):
        return {k: v.value for k, v in value.items()}
    return value

def _ensure_dht_running(dht: DHT, timeout: float = 120.0) -> bool:
    if getattr(dht, "is_alive", False):
        return True
    try:
        dht.run_in_background(await_ready=True, timeout=timeout)
        logger.warning("[DHT] restarted p2pd/DHT (await_ready=%s)", True)
        return True
    except Exception as e:
        logger.error("[DHT] failed to restart: %r", e)
        return False

def get_dht_value(dht: DHT, **kwargs):
    try:
        return _unwrap_value(dht.get(**kwargs))
    except (ConnectionRefusedError, P2PDaemonError, OSError) as e:
        logger.warning("[DHT] get() failed: %r — attempting recovery", e)

    try:
        try:
            dht.shutdown()
        except Exception:
            pass
        if not _ensure_dht_running(dht, timeout=120.0):
            return None
        return _unwrap_value(dht.get(**kwargs))
    except Exception as e2:
        logger.error("[DHT] get() retry failed: %r", e2)
        return None
EOF

# Restart node
echo -e "\n✅ Патч застосовано. Перезапускаю ноду...\n"
sudo systemctl restart gensyn.service && sleep 3 && sudo systemctl status gensyn.service --no-pager
