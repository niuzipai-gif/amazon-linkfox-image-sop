import subprocess
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
