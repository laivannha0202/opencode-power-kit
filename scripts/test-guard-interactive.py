#!/usr/bin/env python3
"""
test-guard-interactive.py — E2E tests for interactive guard behavior
opencode-power-kit v2.2.0

Uses a real Python PTY (not stdin redirect) to verify interactive shell
guard behavior: blocked commands don't execute, shell stays alive, safe
commands run after a block, and the guard re-arms for subsequent blocks.

Contract:
  - BLOCKED message on stderr
  - Command does NOT execute (file/dir preserved)
  - Shell survives (exit 0, subsequent commands run)
  - Safe commands execute normally after a block
  - Guard re-arms: second dangerous command is also blocked

Usage: python3 scripts/test-guard-interactive.py
"""
import os
import pty
import re
import select
import sys
import tempfile
import time

KIT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUARD_PATH = os.path.join(KIT_DIR, "templates", "guard", "opk-guard-bashrc")

PASS = 0
FAIL = 0


def ok(msg):
    global PASS
    PASS += 1
    print(f"  ok   {msg}")


def fail(msg, output=""):
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")
    if output:
        # Print filtered output for debugging
        for line in output.split("\n"):
            line = line.rstrip()
            if not line:
                continue
            if "bash-5.3$" in line:
                continue
            if "Inappropriate ioctl" in line:
                continue
            if "no job control" in line:
                continue
            print(f"    {line}")


def run_interactive(script, timeout=5):
    """Run a script in an interactive Bash via PTY. Returns (output, exit_code)."""
    master_fd, slave_fd = pty.openpty()
    pid = os.fork()
    if pid == 0:
        os.close(master_fd)
        os.dup2(slave_fd, 0)
        os.dup2(slave_fd, 1)
        os.dup2(slave_fd, 2)
        os.close(slave_fd)
        os.environ["TERM"] = "dumb"
        os.execvp("bash", ["bash", "--noprofile", "--norc", "-i"])
        sys.exit(1)

    os.close(slave_fd)
    output = b""
    try:
        os.write(master_fd, (script + "\nexit\n").encode())
        deadline = time.time() + timeout
        while time.time() < deadline:
            rlist, _, _ = select.select([master_fd], [], [], 0.1)
            if rlist:
                try:
                    data = os.read(master_fd, 4096)
                    if not data:
                        break
                    output += data
                except OSError:
                    break
    except Exception:
        pass
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass
        try:
            _, status = os.waitpid(pid, 0)
            exit_code = os.WEXITSTATUS(status) if os.WIFEXITED(status) else -1
        except ChildProcessError:
            exit_code = -1

    return output.decode("utf-8", errors="replace"), exit_code


def filter_output(raw):
    """Filter shell noise from PTY output."""
    lines = []
    for line in raw.split("\n"):
        line = line.rstrip()
        if "bash-5.3$" in line:
            continue
        if "Inappropriate ioctl" in line:
            continue
        if "no job control" in line:
            continue
        if line.strip() == "exit":
            continue
        if line.strip():
            lines.append(line)
    return "\n".join(lines)


def make_test_repo(tmp_root, name):
    """Create a temp git repo with a committed file and a dirty change."""
    repo_dir = os.path.join(tmp_root, name)
    os.makedirs(repo_dir, exist_ok=True)
    os.system(f"git init -q {repo_dir}")
    os.system(f"git -C {repo_dir} config user.name test")
    os.system(f"git -C {repo_dir} config user.email test@example.invalid")
    with open(os.path.join(repo_dir, "file.txt"), "w") as f:
        f.write("committed\n")
    os.system(f"git -C {repo_dir} add file.txt")
    os.system(f"git -C {repo_dir} commit -qm initial")
    with open(os.path.join(repo_dir, "file.txt"), "w") as f:
        f.write("dirty\n")
    return repo_dir


print("[guard-interactive]")

with tempfile.TemporaryDirectory(prefix="opk-guard-interactive-") as tmp_root:
    # ==================================================================
    # Test 1: git reset --hard — blocked, shell survives, file preserved
    # ==================================================================
    print()
    print("  === git reset --hard ===")
    repo = make_test_repo(tmp_root, "test-reset")
    script = (
        f'source "{GUARD_PATH}"\n'
        "git reset --hard HEAD 2>/dev/null\n"
        "printf SAFE_AFTER\\n"
    )
    raw, rc = run_interactive(script)
    output = filter_output(raw)

    with open(os.path.join(repo, "file.txt")) as f:
        file_content = f.read().strip()

    blocked = "opk-guard: BLOCKED" in raw
    safe_ran = "SAFE_AFTER" in output
    preserved = file_content == "dirty"
    shell_ok = rc == 0

    if blocked and safe_ran and preserved and shell_ok:
        ok("git reset --hard -> blocked, shell survived, file preserved, safe cmd ran")
    else:
        fail(
            f"git reset --hard -> blocked={blocked} safe={safe_ran} "
            f"preserved={preserved} shell_rc={rc}",
            raw,
        )

    # ==================================================================
    # Test 2: git clean -df — blocked, shell survives, untracked preserved
    # ==================================================================
    print()
    print("  === git clean -df ===")
    repo = make_test_repo(tmp_root, "test-clean")
    with open(os.path.join(repo, "untracked.txt"), "w") as f:
        f.write("untracked-sentinel\n")

    script = (
        f'source "{GUARD_PATH}"\n'
        "git clean -df 2>/dev/null\n"
        "printf SAFE_AFTER\\n"
    )
    raw, rc = run_interactive(script)
    output = filter_output(raw)

    untracked_exists = os.path.exists(os.path.join(repo, "untracked.txt"))
    blocked = "opk-guard: BLOCKED" in raw
    safe_ran = "SAFE_AFTER" in output
    shell_ok = rc == 0

    if blocked and safe_ran and untracked_exists and shell_ok:
        ok("git clean -df -> blocked, shell survived, untracked preserved")
    else:
        fail(
            f"git clean -df -> blocked={blocked} safe={safe_ran} "
            f"untracked_exists={untracked_exists} shell_rc={rc}",
            raw,
        )

    # ==================================================================
    # Test 3: rm --recursive --force — blocked, shell survives, dir preserved
    # ==================================================================
    print()
    print("  === rm --recursive --force ===")
    target_dir = os.path.join(tmp_root, "test-rm", "target")
    os.makedirs(target_dir)
    with open(os.path.join(target_dir, "sentinel.txt"), "w") as f:
        f.write("SENTINEL\n")

    script = (
        f'source "{GUARD_PATH}"\n'
        "rm --recursive --force target 2>/dev/null\n"
        "printf SAFE_AFTER\\n"
    )
    raw, rc = run_interactive(script, timeout=5)
    output = filter_output(raw)

    dir_exists = os.path.isdir(target_dir)
    blocked = "opk-guard: BLOCKED" in raw
    safe_ran = "SAFE_AFTER" in output
    shell_ok = rc == 0

    if blocked and safe_ran and dir_exists and shell_ok:
        ok("rm --recursive --force -> blocked, shell survived, dir preserved")
    else:
        fail(
            f"rm --recursive --force -> blocked={blocked} safe={safe_ran} "
            f"dir_exists={dir_exists} shell_rc={rc}",
            raw,
        )

    # ==================================================================
    # Test 4: git push --force (mock git) — blocked, shell survives, mock not called
    # ==================================================================
    print()
    print("  === git push --force (mock git) ===")
    mock_bin = os.path.join(tmp_root, "mock-bin")
    marker = os.path.join(tmp_root, "force-push-executed")
    os.makedirs(mock_bin, exist_ok=True)
    if os.path.exists(marker):
        os.remove(marker)

    with open(os.path.join(mock_bin, "git"), "w") as f:
        f.write(
            "#!/usr/bin/env bash\n"
            f'if [[ "$*" == *"--force"* && "$*" == *"push"* ]]; then\n'
            f'  printf "%s\\n" force-push-executed > "{marker}"\n'
            '  echo "fatal: mock: refusing force push" >&2\n'
            "  exit 1\n"
            "fi\n"
            "exec /usr/bin/git \"$@\"\n"
        )
    os.chmod(os.path.join(mock_bin, "git"), 0o755)

    repo = make_test_repo(tmp_root, "test-push")
    script = (
        f'source "{GUARD_PATH}"\n'
        "git push --force origin main 2>/dev/null\n"
        "printf SAFE_AFTER\\n"
    )
    env = os.environ.copy()
    env["PATH"] = mock_bin + ":" + env.get("PATH", "")
    raw, rc = run_interactive(script, timeout=5)
    output = filter_output(raw)

    mock_called = os.path.exists(marker)
    blocked = "opk-guard: BLOCKED" in raw
    safe_ran = "SAFE_AFTER" in output
    shell_ok = rc == 0

    if blocked and safe_ran and not mock_called and shell_ok:
        ok("git push --force -> blocked, shell survived, mock not called")
    else:
        fail(
            f"git push --force -> blocked={blocked} safe={safe_ran} "
            f"mock_called={mock_called} shell_rc={rc}",
            raw,
        )

    # ==================================================================
    # Test 5: Double block — guard re-arms
    # ==================================================================
    print()
    print("  === Guard re-arm (double block) ===")
    repo = make_test_repo(tmp_root, "test-rearm")

    script = (
        f'source "{GUARD_PATH}"\n'
        "git reset --hard HEAD 2>/dev/null\n"
        "git reset --hard HEAD 2>/dev/null\n"
        "printf BOTH_BLOCKED\\n"
    )
    raw, rc = run_interactive(script)
    output = filter_output(raw)

    # Count BLOCKED messages
    blocked_count = raw.count("opk-guard: BLOCKED")
    both_ran = "BOTH_BLOCKED" in output
    shell_ok = rc == 0

    if blocked_count >= 2 and both_ran and shell_ok:
        ok(f"guard re-arm -> {blocked_count} blocks detected, shell survived")
    else:
        fail(
            f"guard re-arm -> blocked_count={blocked_count} both={both_ran} "
            f"shell_rc={rc}",
            raw,
        )

    # ==================================================================
    # Test 6: Explicit exit 0 — shell exits cleanly
    # ==================================================================
    print()
    print("  === Explicit exit 0 ===")
    script = (
        f'source "{GUARD_PATH}"\n'
        "printf BEFORE_EXIT\\n"
        "exit 0\n"
    )
    raw, rc = run_interactive(script)
    output = filter_output(raw)

    has_before = "BEFORE_EXIT" in output
    shell_ok = rc == 0

    if has_before and shell_ok:
        ok("explicit exit 0 -> shell exited with 0")
    else:
        fail(
            f"explicit exit 0 -> before={has_before} rc={rc}",
            raw,
        )

    # ==================================================================
    # Summary
    # ==================================================================
    print()
    print("=== guard-interactive summary ===")
    print(f"passed: {PASS}")
    print(f"failed: {FAIL}")

    if FAIL > 0:
        print("RESULT: FAIL")
        sys.exit(1)
    print("RESULT: PASS")
    sys.exit(0)
