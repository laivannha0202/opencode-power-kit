#!/usr/bin/env python3
"""
test-guard-interactive.py — E2E tests for interactive guard behavior
opencode-power-kit v2.2.0

Uses a real Python PTY (not stdin redirect) to verify interactive shell
<<<<<<< HEAD
guard behavior: blocked commands don't execute, shell stays alive, the
blocked command leaves a nonzero observable status, safe commands run
after a block, and the guard re-arms for subsequent blocks.

Contract:
  - BLOCKED message on stderr (anchored: ^opk-guard: BLOCKED)
  - Command does NOT execute (file/dir preserved)
  - Shell survives (exit 0, subsequent commands run)
  - Blocked status is numeric and nonzero (observer reads $?)
  - Safe commands execute normally after a block (proven by marker file)
  - Guard re-arms: second dangerous command is also blocked
  - PROMPT_COMMAND hooks preserved (string and array forms)
  - Source idempotency: no duplicate hooks/traps

Terminal echo is disabled via termios to prevent false positives from
PTY input echo. An echo self-check verifies echo is truly off.

Stderr is captured on a dedicated pipe (not merged with PTY stdout).
Guard diagnostics are searched ONLY on the stderr stream.
=======
guard behavior: blocked commands don't execute, shell stays alive, safe
commands run after a block, and the guard re-arms for subsequent blocks.

Contract:
  - BLOCKED message on stderr
  - Command does NOT execute (file/dir preserved)
  - Shell survives (exit 0, subsequent commands run)
  - Safe commands execute normally after a block
  - Guard re-arms: second dangerous command is also blocked
>>>>>>> a2bc011

Usage: python3 scripts/test-guard-interactive.py
"""
import os
import pty
import re
import select
import sys
import tempfile
import time
<<<<<<< HEAD
import uuid
=======
>>>>>>> a2bc011

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
<<<<<<< HEAD
=======
        # Print filtered output for debugging
>>>>>>> a2bc011
        for line in output.split("\n"):
            line = line.rstrip()
            if not line:
                continue
<<<<<<< HEAD
=======
            if "bash-5.3$" in line:
                continue
>>>>>>> a2bc011
            if "Inappropriate ioctl" in line:
                continue
            if "no job control" in line:
                continue
            print(f"    {line}")


<<<<<<< HEAD
def run_pty(script, case_dir=None, env_path=None, timeout=8):
    """Run commands prompt-by-prompt in an interactive Bash via PTY.

    Args:
        script: list of command strings to execute sequentially
        case_dir: directory for marker files
        env_path: optional PATH override for mock binaries
        timeout: per-command timeout in seconds

    Returns:
        (stdout, stderr, exit_code) tuple
    """
    master_fd, slave_fd = pty.openpty()

    # Create stderr pipe
    stderr_r, stderr_w = os.pipe()

    pid = os.fork()
    if pid == 0:
        # -- child --
        os.close(master_fd)
        os.close(stderr_r)

        # Redirect stdin and stdout to PTY slave
        os.dup2(slave_fd, 0)
        os.dup2(slave_fd, 1)
        # Redirect stderr to pipe
        os.dup2(stderr_w, 2)
        os.close(slave_fd)
        os.close(stderr_w)

        # Set PATH if mock is needed
        if env_path:
            os.environ["PATH"] = env_path

=======
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
>>>>>>> a2bc011
        os.environ["TERM"] = "dumb"
        os.execvp("bash", ["bash", "--noprofile", "--norc", "-i"])
        sys.exit(1)

<<<<<<< HEAD
    # -- parent --
    os.close(slave_fd)
    os.close(stderr_w)

    # Disable terminal echo
    import termios
    attrs = termios.tcgetattr(master_fd)
    attrs[3] &= ~termios.ECHO       # disable input echo
    attrs[3] &= ~termios.ECHONL     # don't echo NL specially
    termios.tcsetattr(master_fd, termios.TCSANOW, attrs)

    stdout_chunks = []
    stderr_data = b""

    try:
        for cmd in script:
            # Send command + newline
            os.write(master_fd, (cmd + "\n").encode())

            # Read until prompt token appears
            deadline = time.time() + timeout
            prompt_token = "__OPK_PROMPT__"
            while time.time() < deadline:
                rlist, _, _ = select.select([master_fd, stderr_r], [], [], 0.1)
                if master_fd in rlist:
                    try:
                        data = os.read(master_fd, 4096)
                        if not data:
                            break
                        stdout_chunks.append(data)
                        if prompt_token.encode() in data:
                            break
                    except OSError:
                        break
                if stderr_r in rlist:
                    try:
                        data = os.read(stderr_r, 4096)
                        if not data:
                            break
                        stderr_data += data
                    except OSError:
                        break
=======
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
>>>>>>> a2bc011
    except Exception:
        pass
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass
        try:
<<<<<<< HEAD
            os.close(stderr_r)
        except OSError:
            pass
        try:
=======
>>>>>>> a2bc011
            _, status = os.waitpid(pid, 0)
            exit_code = os.WEXITSTATUS(status) if os.WIFEXITED(status) else -1
        except ChildProcessError:
            exit_code = -1

<<<<<<< HEAD
    stdout = b"".join(stdout_chunks).decode("utf-8", errors="replace")
    stderr = stderr_data.decode("utf-8", errors="replace")
    return stdout, stderr, exit_code
=======
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
>>>>>>> a2bc011


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


<<<<<<< HEAD
def write_file(path, content):
    with open(path, "w") as f:
        f.write(content)


def read_file(path):
    if not os.path.exists(path):
        return ""
    with open(path) as f:
        return f.read().strip()


print("[guard-interactive]")

with tempfile.TemporaryDirectory(prefix="opk-guard-interactive-") as tmp_root:

    # ==================================================================
    # Echo self-check: verify echo is truly off
    # ==================================================================
    print()
    print("  === Echo self-check ===")
    echo_token = f"__OPK_ECHO_SELF_{uuid.uuid4().hex[:12]}__"
    stdout, _, _ = run_pty([echo_token])
    if echo_token not in stdout:
        ok("terminal echo disabled — no input echo in PTY output")
    else:
        fail(f"echo self-check failed — token '{echo_token}' found in output", stdout)

    # ==================================================================
    # Test 1: git reset --hard — blocked, status nonzero, shell survives
    # ==================================================================
    print()
    print("  === git reset --hard ===")
    case_dir = os.path.join(tmp_root, "case-reset")
    os.makedirs(case_dir)
    repo = make_test_repo(tmp_root, "test-reset")

    blocked_marker = os.path.join(case_dir, "blocked-executed")
    blocked_status = os.path.join(case_dir, "blocked-status")
    safe_marker = os.path.join(case_dir, "safe-marker")
    safe_token = f"safe_{uuid.uuid4().hex[:12]}"

    prompt = f"__OPK_PROMPT_{uuid.uuid4().hex[:12]}__"

    cmds = [
        f'source "{GUARD_PATH}"',
        f'PS1="{prompt}\\n"',
        f"OPK_FORCE_PUSH_MARKER={blocked_marker} git reset --hard HEAD",
        f'printf "%s\\n" "$?" >"{blocked_status}"',
        f'printf "%s\\n" "{safe_token}" >"{safe_marker}"',
        "exit 0",
    ]
    stdout, stderr, shell_rc = run_pty(cmds, case_dir)

    diag = re.search(r'^opk-guard: BLOCKED', stderr, re.MULTILINE)
    status_val = read_file(blocked_status)
    safe_val = read_file(safe_marker)
    file_content = read_file(os.path.join(repo, "file.txt"))
    safe_marker_exists = os.path.exists(safe_marker)

    status_is_nonzero = status_val.isdigit() and int(status_val) != 0
    blocked = diag is not None
    preserved = file_content == "dirty"
    shell_alive = shell_rc == 0
    safe_ok = safe_val == safe_token

    if blocked and status_is_nonzero and preserved and shell_alive and safe_ok:
        ok(f"git reset --hard -> BLOCKED, status={status_val}, preserved, safe ran")
    else:
        fail(
            f"git reset --hard -> blocked={blocked} status={status_val} "
            f"preserved={preserved} shell_rc={shell_rc} safe={safe_ok}",
            stderr,
        )

    # ==================================================================
    # Test 2: git clean -df — blocked, status nonzero, untracked preserved
    # ==================================================================
    print()
    print("  === git clean -df ===")
    case_dir = os.path.join(tmp_root, "case-clean")
    os.makedirs(case_dir)
    repo = make_test_repo(tmp_root, "test-clean")
    with open(os.path.join(repo, "untracked.txt"), "w") as f:
        f.write("SENTINEL\n")

    blocked_status = os.path.join(case_dir, "blocked-status")
    safe_marker = os.path.join(case_dir, "safe-marker")
    safe_token = f"safe_{uuid.uuid4().hex[:12]}"
    prompt = f"__OPK_PROMPT_{uuid.uuid4().hex[:12]}__"

    cmds = [
        f'source "{GUARD_PATH}"',
        f'PS1="{prompt}\\n"',
        "git clean -df",
        f'printf "%s\\n" "$?" >"{blocked_status}"',
        f'printf "%s\\n" "{safe_token}" >"{safe_marker}"',
        "exit 0",
    ]
    stdout, stderr, shell_rc = run_pty(cmds, case_dir)

    diag = re.search(r'^opk-guard: BLOCKED', stderr, re.MULTILINE)
    status_val = read_file(blocked_status)
    untracked_exists = os.path.exists(os.path.join(repo, "untracked.txt"))
    safe_val = read_file(safe_marker)

    status_is_nonzero = status_val.isdigit() and int(status_val) != 0
    blocked = diag is not None
    shell_alive = shell_rc == 0
    safe_ok = safe_val == safe_token

    if blocked and status_is_nonzero and untracked_exists and shell_alive and safe_ok:
        ok(f"git clean -df -> BLOCKED, status={status_val}, untracked preserved, safe ran")
    else:
        fail(
            f"git clean -df -> blocked={blocked} status={status_val} "
            f"untracked={untracked_exists} shell_rc={shell_rc} safe={safe_ok}",
            stderr,
        )

    # ==================================================================
    # Test 3: rm --recursive --force — blocked, status nonzero, dir preserved
    # ==================================================================
    print()
    print("  === rm --recursive --force ===")
    case_dir = os.path.join(tmp_root, "case-rm")
    os.makedirs(case_dir)
=======
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
>>>>>>> a2bc011
    target_dir = os.path.join(tmp_root, "test-rm", "target")
    os.makedirs(target_dir)
    with open(os.path.join(target_dir, "sentinel.txt"), "w") as f:
        f.write("SENTINEL\n")

<<<<<<< HEAD
    blocked_status = os.path.join(case_dir, "blocked-status")
    safe_marker = os.path.join(case_dir, "safe-marker")
    safe_token = f"safe_{uuid.uuid4().hex[:12]}"
    prompt = f"__OPK_PROMPT_{uuid.uuid4().hex[:12]}__"

    cmds = [
        f'source "{GUARD_PATH}"',
        f'PS1="{prompt}\\n"',
        "rm --recursive --force target",
        f'printf "%s\\n" "$?" >"{blocked_status}"',
        f'printf "%s\\n" "{safe_token}" >"{safe_marker}"',
        "exit 0",
    ]
    stdout, stderr, shell_rc = run_pty(cmds, case_dir)

    diag = re.search(r'^opk-guard: BLOCKED', stderr, re.MULTILINE)
    status_val = read_file(blocked_status)
    dir_exists = os.path.isdir(target_dir)
    sentinel = read_file(os.path.join(target_dir, "sentinel.txt"))
    safe_val = read_file(safe_marker)

    status_is_nonzero = status_val.isdigit() and int(status_val) != 0
    blocked = diag is not None
    shell_alive = shell_rc == 0
    safe_ok = safe_val == safe_token

    if blocked and status_is_nonzero and dir_exists and sentinel == "SENTINEL" and shell_alive and safe_ok:
        ok(f"rm --recursive --force -> BLOCKED, status={status_val}, dir preserved, safe ran")
    else:
        fail(
            f"rm --recursive --force -> blocked={blocked} status={status_val} "
            f"dir_exists={dir_exists} sentinel='{sentinel}' shell_rc={shell_rc} safe={safe_ok}",
            stderr,
        )

    # ==================================================================
    # Test 4: git push --force (mock git) — blocked, status nonzero
    # ==================================================================
    print()
    print("  === git push --force (mock git) ===")
    case_dir = os.path.join(tmp_root, "case-push")
    os.makedirs(case_dir)

    mock_bin = os.path.join(tmp_root, "mock-bin")
    push_marker = os.path.join(case_dir, "force-push-executed")
    os.makedirs(mock_bin, exist_ok=True)
=======
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
>>>>>>> a2bc011

    with open(os.path.join(mock_bin, "git"), "w") as f:
        f.write(
            "#!/usr/bin/env bash\n"
            f'if [[ "$*" == *"--force"* && "$*" == *"push"* ]]; then\n'
<<<<<<< HEAD
            f'  printf "%s\\n" force-push-executed > "{push_marker}"\n'
=======
            f'  printf "%s\\n" force-push-executed > "{marker}"\n'
>>>>>>> a2bc011
            '  echo "fatal: mock: refusing force push" >&2\n'
            "  exit 1\n"
            "fi\n"
            "exec /usr/bin/git \"$@\"\n"
        )
    os.chmod(os.path.join(mock_bin, "git"), 0o755)

    repo = make_test_repo(tmp_root, "test-push")
<<<<<<< HEAD
    blocked_status = os.path.join(case_dir, "blocked-status")
    safe_marker = os.path.join(case_dir, "safe-marker")
    safe_token = f"safe_{uuid.uuid4().hex[:12]}"
    prompt = f"__OPK_PROMPT_{uuid.uuid4().hex[:12]}__"

    cmds = [
        f'source "{GUARD_PATH}"',
        f'PS1="{prompt}\\n"',
        "git push --force origin main",
        f'printf "%s\\n" "$?" >"{blocked_status}"',
        f'printf "%s\\n" "{safe_token}" >"{safe_marker}"',
        "exit 0",
    ]
    stdout, stderr, shell_rc = run_pty(cmds, case_dir, env_path=mock_bin + ":" + os.environ.get("PATH", ""))

    diag = re.search(r'^opk-guard: BLOCKED', stderr, re.MULTILINE)
    mock_called = os.path.exists(push_marker)
    status_val = read_file(blocked_status)
    safe_val = read_file(safe_marker)

    status_is_nonzero = status_val.isdigit() and int(status_val) != 0
    blocked = diag is not None
    shell_alive = shell_rc == 0
    safe_ok = safe_val == safe_token

    if blocked and status_is_nonzero and not mock_called and shell_alive and safe_ok:
        ok(f"git push --force -> BLOCKED, status={status_val}, mock not called, safe ran")
    else:
        fail(
            f"git push --force -> blocked={blocked} status={status_val} "
            f"mock_called={mock_called} shell_rc={shell_rc} safe={safe_ok}",
            stderr,
        )

    # ==================================================================
    # Test 5: Guard re-arm — two consecutive blocked commands
    # ==================================================================
    print()
    print("  === Guard re-arm (double block) ===")
    case_dir = os.path.join(tmp_root, "case-rearm")
    os.makedirs(case_dir)
    repo = make_test_repo(tmp_root, "test-rearm")

    blocked_status_1 = os.path.join(case_dir, "blocked-status-1")
    safe_marker_1 = os.path.join(case_dir, "safe-marker-1")
    safe_token_1 = f"safe1_{uuid.uuid4().hex[:8]}"
    blocked_status_2 = os.path.join(case_dir, "blocked-status-2")
    safe_marker_2 = os.path.join(case_dir, "safe-marker-2")
    safe_token_2 = f"safe2_{uuid.uuid4().hex[:8]}"
    prompt = f"__OPK_PROMPT_{uuid.uuid4().hex[:12]}__"

    cmds = [
        f'source "{GUARD_PATH}"',
        f'PS1="{prompt}\\n"',
        # Block 1
        "git reset --hard HEAD",
        f'printf "%s\\n" "$?" >"{blocked_status_1}"',
        f'printf "%s\\n" "{safe_token_1}" >"{safe_marker_1}"',
        # Block 2
        "git reset --hard HEAD",
        f'printf "%s\\n" "$?" >"{blocked_status_2}"',
        f'printf "%s\\n" "{safe_token_2}" >"{safe_marker_2}"',
        "exit 0",
    ]
    stdout, stderr, shell_rc = run_pty(cmds, case_dir)

    blocked_count = len(re.findall(r'^opk-guard: BLOCKED', stderr, re.MULTILINE))
    sv1 = read_file(blocked_status_1)
    sv2 = read_file(blocked_status_2)
    sm1 = read_file(safe_marker_1)
    sm2 = read_file(safe_marker_2)
    file_content = read_file(os.path.join(repo, "file.txt"))

    s1_ok = sv1.isdigit() and int(sv1) != 0
    s2_ok = sv2.isdigit() and int(sv2) != 0
    shell_alive = shell_rc == 0

    if (blocked_count >= 2 and s1_ok and s2_ok
            and sm1 == safe_token_1 and sm2 == safe_token_2
            and file_content == "dirty" and shell_alive):
        ok(f"guard re-arm -> {blocked_count} blocks, statuses=[{sv1},{sv2}], safe markers present")
    else:
        fail(
            f"guard re-arm -> blocks={blocked_count} status1={sv1} status2={sv2} "
            f"safe1={sm1} safe2={sm2} file='{file_content}' shell_rc={shell_rc}",
            stderr,
        )

    # ==================================================================
    # Test 6: Benign status — true returns 0, false returns 1
    # ==================================================================
    print()
    print("  === Benign status preservation ===")
    case_dir = os.path.join(tmp_root, "case-benign")
    os.makedirs(case_dir)

    status_true = os.path.join(case_dir, "status-true")
    status_false = os.path.join(case_dir, "status-false")
    prompt = f"__OPK_PROMPT_{uuid.uuid4().hex[:12]}__"

    cmds = [
        f'source "{GUARD_PATH}"',
        f'PS1="{prompt}\\n"',
        "true",
        f'printf "%s\\n" "$?" >"{status_true}"',
        "false",
        f'printf "%s\\n" "$?" >"{status_false}"',
        "exit 0",
    ]
    stdout, stderr, shell_rc = run_pty(cmds, case_dir)

    tv = read_file(status_true)
    fv = read_file(status_false)

    if tv == "0" and fv == "1" and shell_rc == 0:
        ok(f"benign status -> true={tv}, false={fv}")
    else:
        fail(f"benign status -> true={tv} false={fv} shell_rc={shell_rc}", stderr)

    # ==================================================================
    # Test 7: Existing string PROMPT_COMMAND preserved
    # ==================================================================
    print()
    print("  === PROMPT_COMMAND string preserved ===")
    case_dir = os.path.join(tmp_root, "case-prompt-str")
    os.makedirs(case_dir)

    prompt_log = os.path.join(case_dir, "prompt-log")
    blocked_status = os.path.join(case_dir, "blocked-status")
    safe_marker = os.path.join(case_dir, "safe-marker")
    safe_token = f"safe_{uuid.uuid4().hex[:12]}"
    prompt = f"__OPK_PROMPT_{uuid.uuid4().hex[:12]}__"

    cmds = [
        f'PROMPT_COMMAND=\'printf "%s\\n" string-hook >>"{prompt_log}"\'',
        f'source "{GUARD_PATH}"',
        f'PS1="{prompt}\\n"',
        "git reset --hard HEAD",
        f'printf "%s\\n" "$?" >"{blocked_status}"',
        f'printf "%s\\n" "{safe_token}" >"{safe_marker}"',
        "exit 0",
    ]
    stdout, stderr, shell_rc = run_pty(cmds, case_dir)

    sv = read_file(blocked_status)
    sm = read_file(safe_marker)
    log_content = read_file(prompt_log)
    diag = re.search(r'^opk-guard: BLOCKED', stderr, re.MULTILINE)
    sv_ok = sv.isdigit() and int(sv) != 0

    if sv_ok and sm == safe_token and "string-hook" in log_content and diag is not None:
        ok(f"string PROMPT_COMMAND preserved, status={sv}")
    else:
        fail(
            f"string PROMPT_COMMAND -> status={sv} safe='{sm}' "
            f"log='{log_content}' diag={diag is not None}",
            stderr,
        )

    # ==================================================================
    # Test 8: Existing array PROMPT_COMMAND preserved
    # ==================================================================
    print()
    print("  === PROMPT_COMMAND array preserved ===")
    case_dir = os.path.join(tmp_root, "case-prompt-arr")
    os.makedirs(case_dir)

    prompt_log = os.path.join(case_dir, "prompt-log")
    blocked_status = os.path.join(case_dir, "blocked-status")
    safe_marker = os.path.join(case_dir, "safe-marker")
    safe_token = f"safe_{uuid.uuid4().hex[:12]}"
    prompt = f"__OPK_PROMPT_{uuid.uuid4().hex[:12]}__"

    cmds = [
        f'PROMPT_COMMAND=(\'printf "%s\\n" hook-one >>"{prompt_log}"\' '
        f'\'printf "%s\\n" hook-two >>"{prompt_log}"\')',
        f'source "{GUARD_PATH}"',
        f'PS1="{prompt}\\n"',
        "git reset --hard HEAD",
        f'printf "%s\\n" "$?" >"{blocked_status}"',
        f'printf "%s\\n" "{safe_token}" >"{safe_marker}"',
        "exit 0",
    ]
    stdout, stderr, shell_rc = run_pty(cmds, case_dir)

    sv = read_file(blocked_status)
    sm = read_file(safe_marker)
    log_content = read_file(prompt_log)
    diag = re.search(r'^opk-guard: BLOCKED', stderr, re.MULTILINE)
    sv_ok = sv.isdigit() and int(sv) != 0

    if (sv_ok and sm == safe_token and "hook-one" in log_content
            and "hook-two" in log_content and diag is not None):
        ok(f"array PROMPT_COMMAND preserved, status={sv}")
    else:
        fail(
            f"array PROMPT_COMMAND -> status={sv} safe='{sm}' "
            f"log='{log_content}' diag={diag is not None}",
            stderr,
        )

    # ==================================================================
    # Test 9: Source idempotency — source guard twice
    # ==================================================================
    print()
    print("  === Source idempotency ===")
    case_dir = os.path.join(tmp_root, "case-idempotent")
    os.makedirs(case_dir)
    repo = make_test_repo(tmp_root, "test-idempotent")

    blocked_status = os.path.join(case_dir, "blocked-status")
    safe_marker = os.path.join(case_dir, "safe-marker")
    safe_token = f"safe_{uuid.uuid4().hex[:12]}"
    prompt = f"__OPK_PROMPT_{uuid.uuid4().hex[:12]}__"

    cmds = [
        f'source "{GUARD_PATH}"',
        f'source "{GUARD_PATH}"',
        f'PS1="{prompt}\\n"',
        "git reset --hard HEAD",
        f'printf "%s\\n" "$?" >"{blocked_status}"',
        f'printf "%s\\n" "{safe_token}" >"{safe_marker}"',
        "exit 0",
    ]
    stdout, stderr, shell_rc = run_pty(cmds, case_dir)

    sv = read_file(blocked_status)
    sm = read_file(safe_marker)
    diag_count = len(re.findall(r'^opk-guard: BLOCKED', stderr, re.MULTILINE))
    file_content = read_file(os.path.join(repo, "file.txt"))
    sv_ok = sv.isdigit() and int(sv) != 0

    if sv_ok and sm == safe_token and diag_count == 1 and file_content == "dirty":
        ok(f"source idempotent -> status={sv}, 1 diagnostic, dirty preserved")
    else:
        fail(
            f"source idempotent -> status={sv} safe='{sm}' "
            f"diags={diag_count} file='{file_content}'",
            stderr,
        )

    # ==================================================================
    # Test 10: Explicit exit 0
    # ==================================================================
    print()
    print("  === Explicit exit 0 ===")
    prompt = f"__OPK_PROMPT_{uuid.uuid4().hex[:12]}__"
    cmds = [
        f'source "{GUARD_PATH}"',
        f'PS1="{prompt}\\n"',
        "printf SAFE_CMD\\n",
        "exit 0",
    ]
    stdout, stderr, shell_rc = run_pty(cmds)

    has_safe = "SAFE_CMD" in stdout
    shell_ok = shell_rc == 0

    if has_safe and shell_ok:
        ok("explicit exit 0 -> shell exited with 0")
    else:
        fail(f"explicit exit 0 -> safe_cmd={has_safe} rc={shell_rc}", stdout)
=======
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
>>>>>>> a2bc011

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
