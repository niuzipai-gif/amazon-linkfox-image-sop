import subprocess
import re
from pathlib import Path


ROOT = Path(__file__).parents[1]
VALIDATOR = ROOT / "scripts" / "validate-sop-skill.ps1"


def run_validator(skill_dir: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(VALIDATOR), "-SkillPath", str(skill_dir)],
        text=True,
        capture_output=True,
        check=False,
    )


def test_valid_fixture_passes():
    result = run_validator(ROOT / "tests" / "fixtures" / "valid-skill")
    assert result.returncode == 0, result.stdout + result.stderr


def test_private_fixture_fails_closed():
    result = run_validator(ROOT / "tests" / "fixtures" / "invalid-private-link")
    assert result.returncode != 0
    assert "private" in (result.stdout + result.stderr).lower()


def test_hard_rule_fixture_fails_closed():
    result = run_validator(ROOT / "tests" / "fixtures" / "invalid-hard-rule")
    assert result.returncode != 0
    assert "270" in (result.stdout + result.stderr)


def test_condition_based_browser_recovery_contract_is_present():
    runtime_files = [
        ROOT / "SKILL.md",
        ROOT / "README.md",
        ROOT / "references" / "browser-preflight.md",
    ]
    text = "\n".join(path.read_text(encoding="utf-8") for path in runtime_files)

    required_terms = (
        "错误指纹",
        "状态变化",
        "时间预算",
        "控制面",
        "同一动作",
    )
    for term in required_terms:
        assert term in text, f"missing condition-based recovery term: {term}"

    fixed_retry = re.compile(r"(?:最多|上限|连续|第\s*[三3])[^\n]{0,12}(?:三次|3\s*次|3次|重试|检查|尝试)")
    assert not fixed_retry.search(text), "runtime docs still impose a fixed three-attempt ceiling"


def test_condition_based_validator_rule_rejects_legacy_fixed_retry_contract():
    result = run_validator(ROOT / "tests" / "fixtures" / "invalid-hard-rule")
    assert result.returncode != 0
    assert "browser-fixed-retry" in (result.stdout + result.stderr)
