#!/usr/bin/env bash
# End-to-end scenarios against GitHub and the Atlantis from `make up`. Each
# scenario opens a pull request with `gh`, drives Atlantis with comments,
# asserts on what it answers and on the CI check, and ends with every plan
# applied. Afterwards the pull request is closed and its branch deleted;
# KEEP_OPEN=1 leaves it open, and only releases its Atlantis locks so the
# next scenario can plan the same stacks. Run one with: atlantis/e2e.sh <name>
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source .env

REPO=$(git remote get-url origin | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#')
BOT="${ATLANTIS_GH_APP_SLUG}[bot]"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
LOG_DIR=${LOG_DIR:-$PWD/.e2e-comments}
mkdir -p "$LOG_DIR"

PR=""
SEEN=0
COMMENT=""

say() { printf '  %s\n' "$*"; }
fail() {
	printf '  FAIL: %s\n' "$*" >&2
	exit 1
}

branch() { # branch NAME: fresh clone on a new branch, cwd is the clone
	rm -rf "$WORK/repo"
	gh repo clone "$REPO" "$WORK/repo" -- -q
	cd "$WORK/repo"
	git checkout -q -b "demo/$1-$(date +%s)"
}

open_pr() { # open_pr TITLE BODY: commit, push, open a pull request
	git add -A
	git commit -qm "$1"
	git push -q -u origin HEAD 2>/dev/null
	PR=$(gh pr create -R "$REPO" --title "$1" --body "$2" | grep -oE '[0-9]+$')
	SEEN=0
	say "PR #$PR https://github.com/$REPO/pull/$PR"
}

comment() { # comment BODY
	SEEN=$(gh api "repos/$REPO/issues/$PR/comments" -f body="$1" --jq .id)
	say "> $1"
}

wait_for() { # wait_for REGEX: next Atlantis comment matching REGEX
	local body
	for _ in $(seq 1 60); do
		body=$(gh api "repos/$REPO/issues/$PR/comments?per_page=100" |
			jq -r --arg bot "$BOT" --argjson after "$SEEN" \
				'[.[] | select(.id > $after and .user.login == $bot)] | last // empty
				 | "\(.id)\n\(.body)"')
		if [ -n "$body" ] && grep -qE "$1" <<<"$body"; then
			SEEN=$(head -1 <<<"$body")
			COMMENT=$(tail -n +2 <<<"$body")
			printf '%s\n' "$COMMENT" >"$LOG_DIR/$SCENARIO-$SEEN.md"
			no_red_lines
			return 0
		fi
		sleep 5
	done
	fail "no Atlantis comment matching /$1/"
}

no_red_lines() { # GitHub renders a line starting with "-" red in Atlantis' diff blocks
	! grep -nE '^-([^-]|$)' <<<"$COMMENT" >&2 || fail "comment has lines GitHub renders red"
}

has() { grep -qF -- "$1" <<<"$COMMENT" || fail "comment lacks: $1"; say "ok: $1"; }
lacks() { ! grep -qF -- "$1" <<<"$COMMENT" || fail "comment has: $1"; say "ok, absent: $1"; }

ci_is() { # ci_is pass|fail: the generated-files check on the head commit
	local state=""
	for _ in $(seq 1 60); do
		state=$(gh pr checks -R "$REPO" "$PR" --json name,bucket \
			--jq '.[] | select(.name == "check") | .bucket' 2>/dev/null || true)
		case "$state" in pass | fail) break ;; esac
		sleep 5
	done
	[ "$state" = "$1" ] || fail "CI check is '$state', expected '$1'"
	say "ok: CI check $1"
}

applied() { # applied N: `atlantis apply` applies all N planned projects
	comment "atlantis apply"
	wait_for 'Ran Apply|Error'
	if [ "$1" = 1 ]; then has 'Apply complete!'; else has "$1 successful, 0 failed, 0 errored"; fi
	lacks 'Apply Failed'
}

finish() {
	ci_is pass
	comment "atlantis unlock"
	wait_for 'unlocked'
	[ -z "${KEEP_OPEN:-}" ] || return 0
	gh pr close -R "$REPO" "$PR" --delete-branch >/dev/null
}

DEV=stacks/aws/acme-development/eu-west-1
PROD=stacks/aws/acme-production/eu-west-1

no_generated_files() {
	[ -z "$(git ls-files '_terramate_generated_*.tf' '*/_terramate_generated_*.tf' atlantis.yaml)" ] ||
		fail "generated files are committed"
}

scenario_account_global() {
	branch account-global
	sed -i.bak 's/"acme-development"/"acme-development-v2"/' stacks/aws/acme-development/account.tm.hcl
	rm stacks/aws/acme-development/account.tm.hcl.bak
	no_generated_files
	open_pr "feat: change a global in one account" "$(
		cat <<'MD'
Changes one global, `account_name`, in `stacks/aws/acme-development/account.tm.hcl`. That is the only file in this pull request.

**What to look for:** every stack in the development account reads this global through its generated Terraform. That generated code isn't committed, so no `.tf` file changed here. Atlantis still plans both development stacks, because `when_modified_from_config` lists the account's `*.tm.hcl` files in their `when_modified`. The production stacks aren't planned.

**Expected:** `aws-acme-development-eu-west-1-network` and `aws-acme-development-eu-west-1-app` planned with the new name, then applied with `atlantis apply`.
MD
	)"
	wait_for 'Ran Plan|Error'
	has 'Ran Plan for 2 projects'
	has 'project: `aws-acme-development-eu-west-1-network`'
	has 'project: `aws-acme-development-eu-west-1-app`'
	has 'acme-development-v2-eu-west-1-network'
	lacks 'acme-production'
	lacks 'shared-settings'
	applied 2
	finish
}

scenario_import() {
	branch import
	perl -pi -e 's/^(\s+)region       = global.region$/$&\n$1cloud        = "aws"/' stacks/imports/aws.tm.hcl
	no_generated_files
	open_pr "feat: change a file only the aws stacks import" "$(
		cat <<'MD'
Adds a local to `stacks/imports/aws.tm.hcl`. That is the only file in this pull request.

**What to look for:** `stacks/aws/aws.tm.hcl` imports this file, so it shapes all four AWS stacks. The `shared/settings` stack doesn't import it. `when_modified_from_config` lists an imported file only in the projects whose config imports it.

**Expected:** the four AWS stacks planned and `shared-settings` not, then the four applied with `atlantis apply`.
MD
	)"
	wait_for 'Ran Plan|Error'
	has 'Ran Plan for 4 projects'
	lacks 'shared-settings'
	applied 4
	finish
}

scenario_module() {
	branch module
	sed -i.bak 's/input = var.name/input = "${var.name}-v2"/' modules/shared/main.tf && rm modules/shared/main.tf.bak
	open_pr "feat: change the shared module" "$(
		cat <<'MD'
Changes `modules/shared/main.tf`. That is the only file in this pull request.

**What to look for:** only the two `app` stacks call this module. `when_modified_from_config` reads the stacks' `.tf` files and adds `modules/shared/**` to the projects that call it.

**Expected:** the two `app` stacks planned and nothing else, then both applied with `atlantis apply`.
MD
	)"
	wait_for 'Ran Plan|Error'
	has 'Ran Plan for 2 projects'
	has 'project: `aws-acme-development-eu-west-1-app`'
	has 'project: `aws-acme-production-eu-west-1-app`'
	lacks 'network'
	applied 2
	finish
}

scenario_watched_file() {
	branch watched-file
	sed -i.bak 's/"replicas": 2/"replicas": 3/' config/settings.json && rm config/settings.json.bak
	open_pr "feat: change a watched file" "$(
		cat <<'MD'
Changes `config/settings.json`, a file outside every stack. That is the only file in this pull request.

**What to look for:** the `shared/settings` stack reads this file and lists it in `watch` in its `stack.tm.hcl`. `when_modified_from_config` adds a stack's `watch` files to its `when_modified`.

**Expected:** `shared-settings` planned and nothing else, then applied with `atlantis apply`.
MD
	)"
	wait_for 'Ran Plan|Error'
	has 'project: `shared-settings`'
	has 'settings-3'
	lacks 'aws-acme'
	applied 1
	finish
}

scenario_dependencies() {
	branch dependencies
	sed -i.bak 's/-${local.stack_name}"/-${local.stack_name}-v2"/' "$DEV/network/main.tf" "$DEV/app/main.tf"
	rm "$DEV/network/main.tf.bak" "$DEV/app/main.tf.bak"
	open_pr "feat: change two stacks that depend on each other" "$(
		cat <<'MD'
Changes the development `network` and `app` stacks. `app` declares `after = ["../network"]` in its `stack.tm.hcl`.

**What to look for:** the generator turns that `after` into Atlantis' `depends_on`. Commenting `atlantis apply -p aws-acme-development-eu-west-1-app` first is refused, because `network` isn't applied yet. A plain `atlantis apply` then applies `network` first and `app` second.

**Expected:** both planned. The first apply comment is refused, the second applies both in order.
MD
	)"
	wait_for 'Ran Plan|Error'
	has 'Ran Plan for 2 projects'
	comment "atlantis apply -p aws-acme-development-eu-west-1-app"
	wait_for 'Ran Apply|Error'
	has "Can't apply your project unless you apply its dependencies"
	applied 2
	finish
}

scenario_new_stack() {
	branch new-stack
	terramate create "$DEV/new-stack" --name new-stack >/dev/null
	cat >"$DEV/new-stack/main.tf" <<'TF'
resource "terraform_data" "this" {
  input = "${local.account_name}-${local.region}-${local.stack_name}"
}
TF
	no_generated_files
	open_pr "feat: add a new stack" "$(
		cat <<'MD'
Adds a brand new stack, `stacks/aws/acme-development/eu-west-1/new-stack`, created with `terramate create`. The pull request has just two files: its `stack.tm.hcl` and `main.tf`.

**What to look for:** neither the stack's generated Terraform nor an `atlantis.yaml` entry is committed. Atlantis' hooks generate both, and the stack is planned as `aws-acme-development-eu-west-1-new-stack`.

**Expected:** one project planned, then applied with `atlantis apply`.
MD
	)"
	wait_for 'Ran Plan|Error'
	has 'project: `aws-acme-development-eu-west-1-new-stack`'
	has 'Plan: 1 to add, 0 to change, 0 to destroy.'
	applied 1
	finish
}

ALL="account_global import module watched_file dependencies new_stack"
for SCENARIO in ${*:-$ALL}; do
	echo "== $SCENARIO"
	(cd "$PWD" && "scenario_$SCENARIO")
done
echo "all scenarios passed"
