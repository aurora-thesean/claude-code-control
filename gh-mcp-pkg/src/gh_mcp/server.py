#!/usr/bin/env python3
"""
gh-mcp: Declarative agile project management MCP server.

Wraps gh CLI — no PAT, no stored tokens, uses existing `gh auth` OAuth session.
Every issue read includes full comment thread. No decontextualised issue reads.
"""
import json
import logging
import shutil
import subprocess
import sys

logging.basicConfig(filename="/tmp/gh-mcp.log", level=logging.DEBUG,
                    format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("gh-mcp")

# ---------------------------------------------------------------------------
# Label taxonomy
# ---------------------------------------------------------------------------

LABELS = {
    # type
    "epic":          ("0052cc", "Large body of work containing stories and features"),
    "story":         ("0075ca", "User story: As a X, I want Y, so that Z"),
    "feature":       ("a2eeef", "User-facing capability"),
    "bug":           ("d73a4a", "Something isn't working"),
    "task":          ("e4e669", "Atomic actionable unit of work"),
    "spike":         ("f9d0c4", "Time-boxed research or investigation"),
    # priority
    "P0-critical":   ("b60205", "Drop everything"),
    "P1-high":       ("e4e669", "This sprint"),
    "P2-medium":     ("0e8a16", "Next sprint"),
    "P3-low":        ("c5def5", "Backlog"),
    # status
    "status:backlog":    ("ededed", "Not yet ready for work"),
    "status:ready":      ("d4c5f9", "Refined, estimated, ready to pull"),
    "status:in-progress":("0075ca", "Being worked on"),
    "status:blocked":    ("b60205", "Cannot proceed"),
    "status:in-review":  ("e4e669", "PR open or awaiting acceptance"),
    "status:done":       ("0e8a16", "Accepted and closed"),
    # points (Fibonacci)
    "points:1":  ("f9d0c4", ""), "points:2":  ("f9d0c4", ""),
    "points:3":  ("f9d0c4", ""), "points:5":  ("f9d0c4", ""),
    "points:8":  ("f9d0c4", ""), "points:13": ("f9d0c4", ""),
    "points:21": ("f9d0c4", ""),
}

STATUS_LABELS = {k for k in LABELS if k.startswith("status:")}
POINT_LABELS  = {k for k in LABELS if k.startswith("points:")}
TYPE_LABELS   = {"epic","story","feature","bug","task","spike"}
PRIO_LABELS   = {"P0-critical","P1-high","P2-medium","P3-low"}

_bootstrapped_repos: set[str] = set()

# ---------------------------------------------------------------------------
# gh execution
# ---------------------------------------------------------------------------

ISSUE_JSON = ("number,title,body,state,labels,assignees,"
              "comments,milestone,url,createdAt,updatedAt")


def gh(*args, input_text=None):
    path = shutil.which("gh")
    if not path:
        return "", "gh CLI not found. Install from https://cli.github.com", 1
    cmd = [path] + list(args)
    log.debug("run: %s", " ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, text=True, input=input_text)
    log.debug("exit=%d out=%r err=%r", r.returncode, r.stdout[:200], r.stderr[:200])
    return r.stdout, r.stderr, r.returncode


def ok(text):
    return [{"type": "text", "text": text.strip() or "(done)"}]


def err(msg, rc=1):
    return [{"type": "text", "text": f"ERROR (exit {rc}): {msg.strip()}"}]


def gh_result(stdout, stderr, rc):
    if rc != 0:
        return err(stderr or stdout, rc)
    return ok(stdout)


def current_user():
    out, _, rc = gh("api", "user", "--jq", ".login")
    return out.strip() if rc == 0 else ""


def set_labels(repo, number, add=(), remove=()):
    for label in add:
        gh("issue", "edit", str(number), "-R", repo, "--add-label", label)
    for label in remove:
        gh("issue", "edit", str(number), "-R", repo, "--remove-label", label)


def replace_status(repo, number, new_status):
    set_labels(repo, number, remove=STATUS_LABELS, add={new_status})


# ---------------------------------------------------------------------------
# Label bootstrap
# ---------------------------------------------------------------------------

def ensure_labels(repo):
    if repo in _bootstrapped_repos:
        return
    out, _, _ = gh("label", "list", "-R", repo, "--json", "name", "--limit", "200")
    try:
        existing = {l["name"] for l in json.loads(out)}
    except Exception:
        existing = set()
    for name, (color, desc) in LABELS.items():
        if name not in existing:
            cmd = ["label", "create", name, "-R", repo, "--color", color]
            if desc:
                cmd += ["--description", desc]
            gh(*cmd)
    _bootstrapped_repos.add(repo)


# ---------------------------------------------------------------------------
# Reading tools (always full context)
# ---------------------------------------------------------------------------

def backlog_view(repo, sprint=None, type_filter=None, priority=None):
    cmd = ["issue", "list", "-R", repo, "--state", "open", "--limit", "200",
           "--json", "number,title,labels,milestone,comments,assignees,updatedAt"]
    if sprint:
        cmd += ["--milestone", sprint]
    out, stderr, rc = gh(*cmd)
    if rc != 0:
        return err(stderr)
    try:
        issues = json.loads(out)
    except Exception:
        return err("Could not parse issue list")

    def get_labels(issue):
        return {l["name"] for l in issue.get("labels", [])}

    def get_type(issue):
        return next((l for l in get_labels(issue) if l in TYPE_LABELS), "untyped")

    def get_priority(issue):
        return next((l for l in get_labels(issue) if l in PRIO_LABELS), "unprioritized")

    def get_points(issue):
        return next((l for l in get_labels(issue) if l in POINT_LABELS), "?pts")

    def get_status(issue):
        return next((l for l in get_labels(issue) if l in STATUS_LABELS), "status:backlog")

    # Apply filters
    if type_filter:
        issues = [i for i in issues if type_filter in get_labels(i)]
    if priority:
        issues = [i for i in issues if priority in get_labels(i)]

    # Group by type then priority
    groups: dict[str, list] = {}
    for issue in issues:
        t = get_type(issue)
        groups.setdefault(t, []).append(issue)

    lines = [f"BACKLOG: {repo}  ({len(issues)} open issues)\n"]
    prio_order = ["P0-critical", "P1-high", "P2-medium", "P3-low", "unprioritized"]
    type_order = ["epic", "story", "feature", "bug", "task", "spike", "untyped"]

    for t in type_order:
        if t not in groups:
            continue
        lines.append(f"\n── {t.upper()} ──")
        bucket = sorted(groups[t],
                        key=lambda i: prio_order.index(get_priority(i))
                        if get_priority(i) in prio_order else 99)
        for i in bucket:
            comments = len(i.get("comments", []))
            milestone = i.get("milestone") or {}
            sprint_name = milestone.get("title", "-")
            assignees = ",".join(a["login"] for a in i.get("assignees", [])) or "-"
            comment_flag = f" [{comments}💬]" if comments else ""
            lines.append(
                f"  #{i['number']:4d}  {get_points(i):8s}  {get_priority(i):12s}"
                f"  {get_status(i):20s}  {sprint_name:12s}  {assignees:12s}"
                f"  {i['title']}{comment_flag}"
            )

    lines.append("\nNOTE: use read_issue to see full context including all comments.")
    return ok("\n".join(lines))


def read_issue(repo, number):
    out, stderr, rc = gh("issue", "view", str(number), "-R", repo,
                         "--json", ISSUE_JSON)
    if rc != 0:
        return err(stderr)
    try:
        issue = json.loads(out)
    except Exception:
        return err("Could not parse issue")

    labels = [l["name"] for l in issue.get("labels", [])]
    assignees = [a["login"] for a in issue.get("assignees", [])]
    milestone = (issue.get("milestone") or {}).get("title", "none")
    comments = issue.get("comments", [])

    lines = [
        f"#{issue['number']}: {issue['title']}",
        f"State:     {issue['state']}",
        f"Labels:    {', '.join(labels) or 'none'}",
        f"Assignees: {', '.join(assignees) or 'none'}",
        f"Sprint:    {milestone}",
        f"URL:       {issue['url']}",
        f"Created:   {issue['createdAt']}  Updated: {issue['updatedAt']}",
        "",
        "── BODY ──",
        issue.get("body") or "(no body)",
        "",
        f"── COMMENTS ({len(comments)}) ──",
    ]
    for c in comments:
        author = c.get("author", {}).get("login", "?")
        lines += [f"\n@{author}  {c.get('createdAt','')}", c.get("body", "")]

    if not comments:
        lines.append("(no comments)")
    return ok("\n".join(lines))


def sprint_status(repo, sprint):
    out, stderr, rc = gh("issue", "list", "-R", repo, "--state", "all",
                         "--milestone", sprint, "--limit", "200",
                         "--json", "number,title,labels,state,assignees")
    if rc != 0:
        return err(stderr)
    try:
        issues = json.loads(out)
    except Exception:
        return err("Could not parse issues")

    def get_status(i):
        ls = {l["name"] for l in i.get("labels", [])}
        if i["state"] == "CLOSED":
            return "done"
        for s in ["status:blocked","status:in-review","status:in-progress","status:ready"]:
            if s in ls:
                return s.replace("status:","")
        return "backlog"

    def get_points(i):
        for l in i.get("labels", []):
            if l["name"].startswith("points:"):
                try:
                    return int(l["name"].split(":")[1])
                except ValueError:
                    pass
        return 0

    buckets: dict[str, list] = {"done":[],"in-review":[],"in-progress":[],"blocked":[],"ready":[],"backlog":[]}
    total_pts = committed_pts = 0
    for i in issues:
        s = get_status(i)
        buckets.setdefault(s, []).append(i)
        pts = get_points(i)
        committed_pts += pts
        if s == "done":
            total_pts += pts

    lines = [f"SPRINT: {sprint}  ({total_pts}/{committed_pts} pts done)\n"]
    for status, items in buckets.items():
        if not items:
            continue
        pts = sum(get_points(i) for i in items)
        lines.append(f"\n── {status.upper()} ({pts} pts) ──")
        for i in items:
            assignees = ",".join(a["login"] for a in i.get("assignees", [])) or "-"
            lines.append(f"  #{i['number']:4d}  {get_points(i):3d}pts  {assignees:12s}  {i['title']}")
    return ok("\n".join(lines))


def epic_tree(repo, number):
    result = read_issue(repo, number)
    out, _, rc = gh("issue", "list", "-R", repo, "--state", "all",
                    "--limit", "200", "--search", f"Part of #{number}",
                    "--json", "number,title,labels,state")
    lines = [result[0]["text"], "\n── CHILDREN ──"]
    if rc == 0:
        try:
            children = json.loads(out)
            for c in children:
                st = "✓" if c["state"] == "CLOSED" else "○"
                ls = {l["name"] for l in c.get("labels",[])}
                t = next((l for l in ls if l in TYPE_LABELS), "")
                lines.append(f"  {st} #{c['number']:4d}  [{t}]  {c['title']}")
        except Exception:
            lines.append("(could not load children)")
    else:
        lines.append("(no children found)")
    return ok("\n".join(lines))


def groom_backlog(repo):
    out, stderr, rc = gh("issue", "list", "-R", repo, "--state", "open",
                         "--limit", "200",
                         "--json", "number,title,labels,assignees,updatedAt,comments")
    if rc != 0:
        return err(stderr)
    try:
        issues = json.loads(out)
    except Exception:
        return err("Could not parse issues")

    import datetime
    now = datetime.datetime.utcnow()
    stale_threshold = datetime.timedelta(days=30)

    untyped, unestimated, unprioritized, blocked, stale, bloated = [], [], [], [], [], []
    for i in issues:
        ls = {l["name"] for l in i.get("labels",[])}
        n, title = i["number"], i["title"]
        if not (ls & TYPE_LABELS):
            untyped.append(f"  #{n}: {title}")
        if not (ls & POINT_LABELS) and ls & {"story","task","feature","bug"}:
            unestimated.append(f"  #{n}: {title}")
        if not (ls & PRIO_LABELS):
            unprioritized.append(f"  #{n}: {title}")
        if "status:blocked" in ls:
            blocked.append(f"  #{n}: {title}")
        try:
            updated = datetime.datetime.fromisoformat(i["updatedAt"].replace("Z","+00:00"))
            if (now.replace(tzinfo=datetime.timezone.utc) - updated) > stale_threshold:
                stale.append(f"  #{n}: {title}")
        except Exception:
            pass
        if len(i.get("comments",[])) > 20:
            bloated.append(f"  #{n}: {title}  ({len(i['comments'])} comments — consider archive_issue)")

    sections = [
        ("UNTYPED (no epic/story/task label)", untyped),
        ("UNESTIMATED stories/tasks", unestimated),
        ("UNPRIORITIZED", unprioritized),
        ("BLOCKED", blocked),
        ("STALE (>30d no activity)", stale),
        ("BLOATED THREADS (consider archiving)", bloated),
    ]
    lines = [f"BACKLOG HEALTH: {repo}\n"]
    for heading, items in sections:
        lines.append(f"── {heading} ({len(items)}) ──")
        lines.extend(items or ["  (none)"])
        lines.append("")
    return ok("\n".join(lines))


# ---------------------------------------------------------------------------
# Creation tools (enforced templates)
# ---------------------------------------------------------------------------

def _create_issue(repo, title, body, labels, milestone=None):
    ensure_labels(repo)
    cmd = ["issue", "create", "-R", repo, "--title", title, "--body", body]
    for label in labels:
        cmd += ["--label", label]
    if milestone:
        cmd += ["--milestone", milestone]
    return gh_result(*gh(*cmd))


def _child_link_footer(parent_number):
    return f"\n\n---\nPart of #{parent_number}" if parent_number else ""


def create_epic(repo, title, problem_statement, success_metrics, acceptance_criteria):
    body = (f"## Problem Statement\n{problem_statement}\n\n"
            f"## Success Metrics\n{success_metrics}\n\n"
            f"## Acceptance Criteria\n{acceptance_criteria}\n\n"
            f"## Stories / Features\n\n<!-- decompose into child issues -->")
    return _create_issue(repo, title, body, ["epic", "status:backlog"])


def create_story(repo, title, as_a, i_want, so_that, acceptance_criteria, epic_number=None):
    body = (f"**As a** {as_a}\n**I want** {i_want}\n**So that** {so_that}\n\n"
            f"## Acceptance Criteria\n{acceptance_criteria}"
            + _child_link_footer(epic_number))
    result = _create_issue(repo, title, body, ["story", "status:backlog"])
    if epic_number:
        _add_child_to_parent(repo, epic_number, title, result)
    return result


def create_feature(repo, title, description, user_value, epic_number=None):
    body = (f"## Description\n{description}\n\n"
            f"## User Value\n{user_value}"
            + _child_link_footer(epic_number))
    result = _create_issue(repo, title, body, ["feature", "status:backlog"])
    if epic_number:
        _add_child_to_parent(repo, epic_number, title, result)
    return result


def create_bug(repo, title, steps_to_reproduce, expected, actual, severity, parent_number=None):
    body = (f"## Steps to Reproduce\n{steps_to_reproduce}\n\n"
            f"## Expected\n{expected}\n\n"
            f"## Actual\n{actual}\n\n"
            f"## Severity\n{severity}"
            + _child_link_footer(parent_number))
    sev_label = {"critical":"P0-critical","high":"P1-high",
                 "medium":"P2-medium","low":"P3-low"}.get(severity.lower(), "P2-medium")
    return _create_issue(repo, title, body, ["bug", sev_label, "status:backlog"])


def create_task(repo, title, description, acceptance_criteria, parent_number=None):
    body = (f"## Description\n{description}\n\n"
            f"## Acceptance Criteria\n{acceptance_criteria}"
            + _child_link_footer(parent_number))
    result = _create_issue(repo, title, body, ["task", "status:backlog"])
    if parent_number:
        _add_child_to_parent(repo, parent_number, title, result)
    return result


def create_spike(repo, title, question_to_answer, timebox_hours, parent_number=None):
    body = (f"## Question to Answer\n{question_to_answer}\n\n"
            f"## Timebox\n{timebox_hours} hours\n\n"
            f"## Output\n<!-- document findings here -->"
            + _child_link_footer(parent_number))
    result = _create_issue(repo, title, body, ["spike", "status:backlog"])
    if parent_number:
        _add_child_to_parent(repo, parent_number, title, result)
    return result


def _add_child_to_parent(repo, parent_number, child_title, child_result):
    try:
        child_num = child_result[0]["text"].split("/issues/")[-1].strip()
        line = f"\n- [ ] #{child_num} {child_title}"
        out, _, rc = gh("issue", "view", str(parent_number), "-R", repo, "--json", "body")
        if rc == 0:
            body = json.loads(out).get("body", "")
            gh("issue", "edit", str(parent_number), "-R", repo, "--body", body + line)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Grooming tools
# ---------------------------------------------------------------------------

def decompose(repo, number, children):
    ensure_labels(repo)
    created = []
    for child in children:
        t = child.get("type", "task")
        child_title = child.get("title", "")
        desc = child.get("description", "")
        if t == "story":
            r = create_story(repo, child_title, "user", desc, "", "", number)
        elif t == "bug":
            r = create_bug(repo, child_title, desc, "", "", "medium", number)
        elif t == "spike":
            r = create_spike(repo, child_title, desc, 4, number)
        else:
            r = create_task(repo, child_title, desc, "", number)
        created.append(r[0]["text"])
    return ok(f"Decomposed #{number} into {len(created)} children:\n" + "\n".join(created))


def archive_issue(repo, number, reason, replacement_titles=None):
    summary_comment = (f"## Archiving this issue\n\n**Reason:** {reason}\n\n"
                       "This issue has been closed to manage complexity. "
                       "Context is preserved in the comment thread above.")
    gh("issue", "comment", str(number), "-R", repo, "--body", summary_comment)
    gh("issue", "close", str(number), "-R", repo)
    created = []
    if replacement_titles:
        for rt in replacement_titles:
            body = f"Scoped from archived issue #{number}.\n\n## Description\n<!-- fill in -->"
            out, _, rc = gh("issue", "create", "-R", repo,
                            "--title", rt, "--body", body, "--label", "status:backlog")
            if rc == 0:
                created.append(out.strip())
    msg = f"Archived #{number}."
    if created:
        msg += f"\nCreated {len(created)} replacements:\n" + "\n".join(created)
    return ok(msg)


def estimate(repo, number, points):
    ensure_labels(repo)
    label = f"points:{points}"
    if label not in POINT_LABELS:
        return err(f"Invalid points. Use: {sorted(POINT_LABELS)}")
    set_labels(repo, number, remove=POINT_LABELS, add={label})
    return ok(f"#{number} estimated at {points} points")


def prioritize(repo, number, priority):
    ensure_labels(repo)
    if priority not in PRIO_LABELS:
        return err(f"Invalid priority. Use: {sorted(PRIO_LABELS)}")
    set_labels(repo, number, remove=PRIO_LABELS, add={priority})
    return ok(f"#{number} priority set to {priority}")


def link_parent(repo, child_number, parent_number):
    out, _, rc = gh("issue", "view", str(child_number), "-R", repo, "--json", "body,title")
    if rc != 0:
        return err(f"Cannot read #{child_number}")
    data = json.loads(out)
    new_body = data["body"] + _child_link_footer(parent_number)
    gh("issue", "edit", str(child_number), "-R", repo, "--body", new_body)
    _add_child_to_parent(repo, parent_number, data["title"],
                         [{"text": f"placeholder/issues/{child_number}"}])
    return ok(f"Linked #{child_number} -> parent #{parent_number}")


# ---------------------------------------------------------------------------
# Sprint tools
# ---------------------------------------------------------------------------

def sprint_create(repo, name, goal, due_date=None):
    cmd = ["api", f"repos/{repo}/milestones", "--method", "POST",
           "--field", f"title={name}", "--field", f"description={goal}"]
    if due_date:
        cmd += ["--field", f"due_on={due_date}T00:00:00Z"]
    return gh_result(*gh(*cmd))


def sprint_assign(repo, sprint, issue_numbers):
    out, _, rc = gh("api", f"repos/{repo}/milestones",
                    "--jq", f'[.[] | select(.title=="{sprint}") | .number][0]')
    if rc != 0 or not out.strip():
        return err(f"Sprint '{sprint}' not found")
    milestone_id = out.strip()
    results = []
    for n in issue_numbers:
        _, stderr, rc2 = gh("api", f"repos/{repo}/issues/{n}",
                            "--method", "PATCH", "--field", f"milestone={milestone_id}")
        results.append(f"#{n}: {'ok' if rc2==0 else stderr.strip()}")
    return ok("\n".join(results))


def sprint_close(repo, sprint):
    status_result = sprint_status(repo, sprint)
    out, _, rc = gh("api", f"repos/{repo}/milestones",
                    "--jq", f'[.[] | select(.title=="{sprint}") | .number][0]')
    if rc == 0 and out.strip():
        gh("api", f"repos/{repo}/milestones/{out.strip()}",
           "--method", "PATCH", "--field", "state=closed")
    return ok(f"Sprint '{sprint}' closed.\n\n" + status_result[0]["text"])


# ---------------------------------------------------------------------------
# Workflow tools
# ---------------------------------------------------------------------------

def start_work(repo, number):
    user = current_user()
    replace_status(repo, number, "status:in-progress")
    if user:
        gh("issue", "edit", str(number), "-R", repo, "--add-assignee", user)
    return ok(f"#{number} in-progress" + (f", assigned to {user}" if user else ""))


def block_issue(repo, number, reason, blocker_number=None):
    replace_status(repo, number, "status:blocked")
    msg = f"**Blocked:** {reason}"
    if blocker_number:
        msg += f"\n\nBlocking issue: #{blocker_number}"
    gh("issue", "comment", str(number), "-R", repo, "--body", msg)
    return ok(f"#{number} marked blocked")


def unblock_issue(repo, number):
    replace_status(repo, number, "status:ready")
    gh("issue", "comment", str(number), "-R", repo, "--body", "Unblocked — moved to ready.")
    return ok(f"#{number} unblocked")


def submit_for_review(repo, number):
    replace_status(repo, number, "status:in-review")
    return ok(f"#{number} in-review")


def accept_story(repo, number, comment=None):
    replace_status(repo, number, "status:done")
    body = f"**Accepted.** {comment}" if comment else "**Accepted.**"
    gh("issue", "comment", str(number), "-R", repo, "--body", body)
    gh("issue", "close", str(number), "-R", repo)
    return ok(f"#{number} accepted and closed")


def setup_labels(repo):
    _bootstrapped_repos.discard(repo)
    ensure_labels(repo)
    return ok(f"Label taxonomy bootstrapped for {repo}")


# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------

TOOLS = [
    {"name":"backlog_view","description":"Full backlog grouped by type and priority. Shows comment counts so you know when context is buried.","inputSchema":{"type":"object","properties":{"repo":{"type":"string","description":"owner/repo"},"sprint":{"type":"string"},"type":{"type":"string"},"priority":{"type":"string"}},"required":["repo"]}},
    {"name":"read_issue","description":"Read a single issue with FULL context: body, ALL comments, labels, assignees, milestone. Never omits comments.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"}},"required":["repo","number"]}},
    {"name":"sprint_status","description":"Sprint burndown grouped by status with point totals.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"sprint":{"type":"string"}},"required":["repo","sprint"]}},
    {"name":"epic_tree","description":"Show epic and all children recursively with status.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"}},"required":["repo","number"]}},
    {"name":"groom_backlog","description":"Health report: untyped, unestimated, unprioritized, blocked, stale, bloated issues.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"}},"required":["repo"]}},
    {"name":"create_epic","description":"Create an epic with problem statement, success metrics, acceptance criteria.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"title":{"type":"string"},"problem_statement":{"type":"string"},"success_metrics":{"type":"string"},"acceptance_criteria":{"type":"string"}},"required":["repo","title","problem_statement","success_metrics","acceptance_criteria"]}},
    {"name":"create_story","description":"Create a user story: As a X / I want Y / So that Z.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"title":{"type":"string"},"as_a":{"type":"string"},"i_want":{"type":"string"},"so_that":{"type":"string"},"acceptance_criteria":{"type":"string"},"epic_number":{"type":"integer"}},"required":["repo","title","as_a","i_want","so_that","acceptance_criteria"]}},
    {"name":"create_feature","description":"Create a user-facing feature linked to an epic.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"title":{"type":"string"},"description":{"type":"string"},"user_value":{"type":"string"},"epic_number":{"type":"integer"}},"required":["repo","title","description","user_value"]}},
    {"name":"create_bug","description":"Create a bug report with repro steps and severity.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"title":{"type":"string"},"steps_to_reproduce":{"type":"string"},"expected":{"type":"string"},"actual":{"type":"string"},"severity":{"type":"string","enum":["critical","high","medium","low"]},"parent_number":{"type":"integer"}},"required":["repo","title","steps_to_reproduce","expected","actual","severity"]}},
    {"name":"create_task","description":"Create an atomic actionable task linked to a parent story.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"title":{"type":"string"},"description":{"type":"string"},"acceptance_criteria":{"type":"string"},"parent_number":{"type":"integer"}},"required":["repo","title","description","acceptance_criteria"]}},
    {"name":"create_spike","description":"Create a time-boxed research spike with a specific question to answer.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"title":{"type":"string"},"question_to_answer":{"type":"string"},"timebox_hours":{"type":"number"},"parent_number":{"type":"integer"}},"required":["repo","title","question_to_answer","timebox_hours"]}},
    {"name":"decompose","description":"Break an epic or story into typed child issues. Updates parent checklist.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"},"children":{"type":"array","items":{"type":"object","properties":{"type":{"type":"string","enum":["story","feature","bug","task","spike"]},"title":{"type":"string"},"description":{"type":"string"}},"required":["type","title"]}}},"required":["repo","number","children"]}},
    {"name":"archive_issue","description":"Close a bloated issue with summary comment. Creates focused stub replacements if titles provided. Use when thread is too long to reason about.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"},"reason":{"type":"string"},"replacement_titles":{"type":"array","items":{"type":"string"}}},"required":["repo","number","reason"]}},
    {"name":"estimate","description":"Set Fibonacci story points (1,2,3,5,8,13,21).","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"},"points":{"type":"integer","enum":[1,2,3,5,8,13,21]}},"required":["repo","number","points"]}},
    {"name":"prioritize","description":"Set priority: P0-critical, P1-high, P2-medium, P3-low.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"},"priority":{"type":"string","enum":["P0-critical","P1-high","P2-medium","P3-low"]}},"required":["repo","number","priority"]}},
    {"name":"link_parent","description":"Establish parent-child relationship between two issues.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"child_number":{"type":"integer"},"parent_number":{"type":"integer"}},"required":["repo","child_number","parent_number"]}},
    {"name":"sprint_create","description":"Create a sprint as a GitHub milestone.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"name":{"type":"string"},"goal":{"type":"string"},"due_date":{"type":"string","description":"YYYY-MM-DD"}},"required":["repo","name","goal"]}},
    {"name":"sprint_assign","description":"Assign issues to a sprint milestone.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"sprint":{"type":"string"},"issue_numbers":{"type":"array","items":{"type":"integer"}}},"required":["repo","sprint","issue_numbers"]}},
    {"name":"sprint_close","description":"Close sprint, report velocity, list unfinished items.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"sprint":{"type":"string"}},"required":["repo","sprint"]}},
    {"name":"start_work","description":"Assign to current gh user and mark in-progress.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"}},"required":["repo","number"]}},
    {"name":"block_issue","description":"Mark blocked with reason and optional blocker issue number.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"},"reason":{"type":"string"},"blocker_number":{"type":"integer"}},"required":["repo","number","reason"]}},
    {"name":"unblock_issue","description":"Remove blocked status, restore to ready.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"}},"required":["repo","number"]}},
    {"name":"submit_for_review","description":"Mark in-review.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"}},"required":["repo","number"]}},
    {"name":"accept_story","description":"PO acceptance: close issue with done status.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"},"number":{"type":"integer"},"comment":{"type":"string"}},"required":["repo","number"]}},
    {"name":"setup_labels","description":"Bootstrap full agile label taxonomy. Idempotent.","inputSchema":{"type":"object","properties":{"repo":{"type":"string"}},"required":["repo"]}},
    {"name":"gh_run","description":"Escape hatch: run an arbitrary gh CLI command.","inputSchema":{"type":"object","properties":{"args":{"type":"array","items":{"type":"string"}}},"required":["args"]}},
]


# ---------------------------------------------------------------------------
# Tool dispatch
# ---------------------------------------------------------------------------

def call_tool(name, a):
    dispatch = {
        "backlog_view":      lambda: backlog_view(a["repo"], a.get("sprint"), a.get("type"), a.get("priority")),
        "read_issue":        lambda: read_issue(a["repo"], a["number"]),
        "sprint_status":     lambda: sprint_status(a["repo"], a["sprint"]),
        "epic_tree":         lambda: epic_tree(a["repo"], a["number"]),
        "groom_backlog":     lambda: groom_backlog(a["repo"]),
        "create_epic":       lambda: create_epic(a["repo"], a["title"], a["problem_statement"], a["success_metrics"], a["acceptance_criteria"]),
        "create_story":      lambda: create_story(a["repo"], a["title"], a["as_a"], a["i_want"], a["so_that"], a["acceptance_criteria"], a.get("epic_number")),
        "create_feature":    lambda: create_feature(a["repo"], a["title"], a["description"], a["user_value"], a.get("epic_number")),
        "create_bug":        lambda: create_bug(a["repo"], a["title"], a["steps_to_reproduce"], a["expected"], a["actual"], a["severity"], a.get("parent_number")),
        "create_task":       lambda: create_task(a["repo"], a["title"], a["description"], a["acceptance_criteria"], a.get("parent_number")),
        "create_spike":      lambda: create_spike(a["repo"], a["title"], a["question_to_answer"], a["timebox_hours"], a.get("parent_number")),
        "decompose":         lambda: decompose(a["repo"], a["number"], a["children"]),
        "archive_issue":     lambda: archive_issue(a["repo"], a["number"], a["reason"], a.get("replacement_titles")),
        "estimate":          lambda: estimate(a["repo"], a["number"], a["points"]),
        "prioritize":        lambda: prioritize(a["repo"], a["number"], a["priority"]),
        "link_parent":       lambda: link_parent(a["repo"], a["child_number"], a["parent_number"]),
        "sprint_create":     lambda: sprint_create(a["repo"], a["name"], a["goal"], a.get("due_date")),
        "sprint_assign":     lambda: sprint_assign(a["repo"], a["sprint"], a["issue_numbers"]),
        "sprint_close":      lambda: sprint_close(a["repo"], a["sprint"]),
        "start_work":        lambda: start_work(a["repo"], a["number"]),
        "block_issue":       lambda: block_issue(a["repo"], a["number"], a["reason"], a.get("blocker_number")),
        "unblock_issue":     lambda: unblock_issue(a["repo"], a["number"]),
        "submit_for_review": lambda: submit_for_review(a["repo"], a["number"]),
        "accept_story":      lambda: accept_story(a["repo"], a["number"], a.get("comment")),
        "setup_labels":      lambda: setup_labels(a["repo"]),
        "gh_run":            lambda: gh_result(*gh(*a["args"])),
    }
    fn = dispatch.get(name)
    if not fn:
        return err(f"Unknown tool: {name}")
    try:
        return fn()
    except KeyError as e:
        return err(f"Missing required argument: {e}")
    except Exception as e:
        log.exception("tool error")
        return err(str(e))


# ---------------------------------------------------------------------------
# MCP stdio protocol
# ---------------------------------------------------------------------------

def send(obj):
    line = json.dumps(obj)
    log.debug("send: %s", line[:300])
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


def handle(msg):
    method = msg.get("method", "")
    mid = msg.get("id")
    if method == "initialize":
        send({"jsonrpc":"2.0","id":mid,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"gh-mcp","version":"0.2.0"}}})
    elif method == "initialized":
        pass
    elif method == "tools/list":
        send({"jsonrpc":"2.0","id":mid,"result":{"tools":TOOLS}})
    elif method == "tools/call":
        p = msg.get("params", {})
        content = call_tool(p.get("name",""), p.get("arguments",{}))
        send({"jsonrpc":"2.0","id":mid,"result":{"content":content,"isError":content[0]["text"].startswith("ERROR")}})
    elif method == "ping":
        send({"jsonrpc":"2.0","id":mid,"result":{}})
    elif mid is not None:
        send({"jsonrpc":"2.0","id":mid,"error":{"code":-32601,"message":f"Unknown method: {method}"}})


def main():
    log.info("gh-mcp v0.2.0 starting")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            handle(json.loads(line))
        except json.JSONDecodeError as e:
            log.error("bad JSON: %s", e)
        except Exception:
            log.exception("unhandled")
