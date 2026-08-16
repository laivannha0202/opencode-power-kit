#!/usr/bin/env python3
"""Real PTY E2E tests for the generated OPK interactive Bash guard."""
from __future__ import annotations

import os
import pty
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import termios
import time
from pathlib import Path

KIT_DIR = Path(__file__).resolve().parent.parent
GUARD = KIT_DIR / "templates" / "guard" / "opk-guard-bashrc"
PASS = 0
FAIL = 0


def ok(msg: str) -> None:
    global PASS
    PASS += 1
    print(f"  ok   {msg}")


def fail(msg: str, output: str = "") -> None:
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")
    for line in output.splitlines()[-30:]:
        print(f"    {line}")


def run_interactive(commands: list[str], *, cwd: Path, env_extra: dict[str, str] | None = None, timeout: float = 8.0) -> tuple[str, int]:
    master_fd, slave_fd = pty.openpty()
    attrs = termios.tcgetattr(slave_fd)
    attrs[3] &= ~termios.ECHO
    attrs[3] &= ~termios.ECHONL
    termios.tcsetattr(slave_fd, termios.TCSANOW, attrs)

    pid = os.fork()
    if pid == 0:
        try:
            os.setsid()
        except OSError:
            pass
        os.chdir(cwd)
        os.close(master_fd)
        os.dup2(slave_fd, 0)
        os.dup2(slave_fd, 1)
        os.dup2(slave_fd, 2)
        if slave_fd > 2:
            os.close(slave_fd)
        env = os.environ.copy()
        env["TERM"] = "dumb"
        env["PS1"] = "__OPK_PROMPT__ "
        if env_extra:
            env.update(env_extra)
        os.execvpe("bash", ["bash", "--noprofile", "--norc", "-i"], env)
        os._exit(127)

    os.close(slave_fd)
    os.write(master_fd, ("\n".join(commands + ["exit 0", ""]) ).encode())
    output = bytearray()
    deadline = time.monotonic() + timeout
    raw_status = None
    try:
        while time.monotonic() < deadline:
            ready, _, _ = select.select([master_fd], [], [], 0.1)
            if ready:
                try:
                    chunk = os.read(master_fd, 8192)
                except OSError:
                    break
                if not chunk:
                    break
                output.extend(chunk)
            waited, st = os.waitpid(pid, os.WNOHANG)
            if waited == pid:
                raw_status = st
                break
        if raw_status is None:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            _, raw_status = os.waitpid(pid, 0)
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass
    return output.decode("utf-8", errors="replace"), os.waitstatus_to_exitcode(raw_status)


def make_repo(root: Path, name: str) -> Path:
    repo = root / name
    repo.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "OPK Test"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "opk@example.invalid"], cwd=repo, check=True)
    (repo / "file.txt").write_text("committed\n", encoding="utf-8")
    subprocess.run(["git", "add", "file.txt"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-qm", "initial"], cwd=repo, check=True)
    (repo / "file.txt").write_text("dirty\n", encoding="utf-8")
    return repo


def status_after(output: str) -> int | None:
    match = re.search(r"__STATUS__(\d+)", output)
    return int(match.group(1)) if match else None


def blocked(output: str) -> bool:
    return "opk-guard: BLOCKED" in output


if not GUARD.is_file() or shutil.which("bash") is None or shutil.which("git") is None:
    raise SystemExit("guard/bash/git missing")

print("[guard-interactive]")
with tempfile.TemporaryDirectory(prefix="opk-guard-interactive-") as raw_tmp:
    tmp = Path(raw_tmp)

    repo = make_repo(tmp, "reset")
    out, rc = run_interactive([
        f'source "{GUARD}"',
        "git reset --hard HEAD",
        'printf "__STATUS__%s\\n" "$?"',
        'printf "__SAFE_AFTER__\\n"',
    ], cwd=repo)
    # DEBUG/extdebug proves enforcement by skipping the command. Bash does not
    # guarantee a portable non-zero `$?` for a skipped interactive command,
    # so assert the actual security contract: block + no side effect + live shell.
    if blocked(out) and (repo / "file.txt").read_text().strip() == "dirty" and "__SAFE_AFTER__" in out and rc == 0:
        ok("git reset --hard blocked; file preserved; shell survives")
    else:
        fail(f"reset blocked={blocked(out)} rc={rc}", out)

    repo = make_repo(tmp, "clean")
    sentinel = repo / "untracked.txt"
    sentinel.write_text("keep\n", encoding="utf-8")
    out, rc = run_interactive([f'source "{GUARD}"', "git clean -df", 'printf "__SAFE_AFTER__\\n"'], cwd=repo)
    if blocked(out) and sentinel.exists() and "__SAFE_AFTER__" in out and rc == 0:
        ok("git clean -df blocked; untracked file preserved")
    else:
        fail(f"clean blocked={blocked(out)} exists={sentinel.exists()} rc={rc}", out)

    rm_case = tmp / "rm-case"
    (rm_case / "target").mkdir(parents=True)
    (rm_case / "target" / "sentinel").write_text("keep\n", encoding="utf-8")
    out, rc = run_interactive([f'source "{GUARD}"', "rm -rf target", 'printf "__SAFE_AFTER__\\n"'], cwd=rm_case)
    if blocked(out) and (rm_case / "target" / "sentinel").exists() and "__SAFE_AFTER__" in out and rc == 0:
        ok("rm -rf blocked; real target preserved")
    else:
        fail(f"rm blocked={blocked(out)} target={(rm_case / 'target').exists()} rc={rc}", out)

    repo = make_repo(tmp, "push")
    mock_bin = tmp / "mock-bin"
    mock_bin.mkdir()
    marker = tmp / "force-push-executed"
    real_git = shutil.which("git")
    mock_git = mock_bin / "git"
    mock_git.write_text("#!/usr/bin/env bash\n" + f'printf "called\\n" > "{marker}"\n' + f'exec "{real_git}" "$@"\n', encoding="utf-8")
    mock_git.chmod(0o755)
    out, rc = run_interactive([f'source "{GUARD}"', "git push --force origin main", 'printf "__SAFE_AFTER__\\n"'], cwd=repo, env_extra={"PATH": f"{mock_bin}:{os.environ.get('PATH', '')}"})
    if blocked(out) and not marker.exists() and "__SAFE_AFTER__" in out and rc == 0:
        ok("force push blocked before mock git")
    else:
        fail(f"push blocked={blocked(out)} mock={marker.exists()} rc={rc}", out)

    ssh_bin = tmp / "ssh-bin"
    ssh_bin.mkdir()
    ssh_marker = tmp / "ssh-executed"
    mock_ssh = ssh_bin / "ssh"
    mock_ssh.write_text("#!/usr/bin/env bash\n" + f'printf "called\\n" > "{ssh_marker}"\nexit 0\n', encoding="utf-8")
    mock_ssh.chmod(0o755)
    out, rc = run_interactive([f'source "{GUARD}"', 'ssh example.invalid "rm -rf /tmp/opk-never"', 'printf "__SAFE_AFTER__\\n"'], cwd=tmp, env_extra={"PATH": f"{ssh_bin}:{os.environ.get('PATH', '')}"})
    if blocked(out) and not ssh_marker.exists() and "__SAFE_AFTER__" in out and rc == 0:
        ok('ssh "rm -rf ..." blocked before ssh execution')
    else:
        fail(f"ssh blocked={blocked(out)} mock={ssh_marker.exists()} rc={rc}", out)

    repo = make_repo(tmp, "rearm")
    out, rc = run_interactive([f'source "{GUARD}"', "git reset --hard HEAD", "git clean -df", 'printf "__BOTH_BLOCKED__\\n"'], cwd=repo)
    if out.count("opk-guard: BLOCKED") >= 2 and "__BOTH_BLOCKED__" in out and rc == 0:
        ok("guard re-arms after first block")
    else:
        fail(f"rearm blocks={out.count('opk-guard: BLOCKED')} rc={rc}", out)

print(f"\npassed: {PASS}")
print(f"failed: {FAIL}")
raise SystemExit(1 if FAIL else 0)
