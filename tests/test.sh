#!/usr/bin/env bash
set -euo pipefail

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

assert_file() {
	[ -f "$1" ] || fail "expected file: $1"
}

assert_no_file() {
	[ ! -e "$1" ] || fail "unexpected file: $1"
}

assert_contains() {
	grep -Fq -- "$2" "$1" || fail "expected '$2' in $1"
}

assert_not_contains() {
	if grep -Fq -- "$2" "$1"; then
		fail "unexpected '$2' in $1"
	fi
}

assert_equals() {
	[ "$1" = "$2" ] || fail "expected '$1', got '$2'"
}

script_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -P -- "$script_dir/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/nisshi-test.XXXXXX")"
trap 'rm -rf -- "$test_root"' EXIT

command -v make >/dev/null 2>&1 || fail "make is required"
command -v pandoc >/dev/null 2>&1 || fail "pandoc is required"

bash -n "$project_root/nisshi.sh" "$project_root/tests/test.sh"
if command -v shellcheck >/dev/null 2>&1; then
	shellcheck "$project_root/nisshi.sh" "$project_root/tests/test.sh"
fi

test_project="$test_root/project"
mkdir -p "$test_project"
test_project="$(cd -P -- "$test_project" && pwd)"
cp "$project_root/Makefile" "$project_root/nisshi.sh" "$test_project/"
cp -R "$project_root/assets" "$test_project/"

make -C "$test_project" >/dev/null
assert_file "$test_project/site/index.html"

mock_bin="$test_root/mock-bin"
open_log="$test_root/open.log"
mkdir -p "$mock_bin"
cat <<-'MOCK' > "$mock_bin/uname"
	#!/bin/sh
	printf '%s\n' Linux
MOCK
cat <<-'MOCK' > "$mock_bin/wslpath"
	#!/bin/sh
	printf '%s\n' 'C:\nisshi\site\index.html'
MOCK
cat <<-'MOCK' > "$mock_bin/explorer.exe"
	#!/bin/sh
	printf '%s\n' "$1" > "$OPEN_LOG"
MOCK
cat <<-'MOCK' > "$mock_bin/xdg-open"
	#!/bin/sh
	printf '%s\n' xdg-open > "$OPEN_LOG"
MOCK
chmod +x "$mock_bin/uname" "$mock_bin/wslpath" "$mock_bin/explorer.exe" "$mock_bin/xdg-open"
WSL_INTEROP=1 OPEN_LOG="$open_log" PATH="$mock_bin:$PATH" "$test_project/nisshi.sh" open
assert_equals 'C:\nisshi\site\index.html' "$(cat "$open_log")"

"$test_project/nisshi.sh" touch 20200102
"$test_project/nisshi.sh" touch 20200103
assert_file "$test_project/src/2020/01/02.md"
assert_contains "$test_project/src/2020/01/02.md" "title: 2020年 01月 02日"

expected_path="$test_project/src/2020/01/02.md"
actual_path="$("$test_project/nisshi.sh" getpath 20200102)"
[ "$actual_path" = "$expected_path" ] || fail "unexpected getpath output"

mkdir -p "$test_root/bin"
ln -s ../project/nisshi.sh "$test_root/bin/nisshi"
actual_path="$("$test_root/bin/nisshi" getpath 20200102)"
[ "$actual_path" = "$expected_path" ] || fail "relative symlink was not resolved"

if "$test_project/nisshi.sh" edit 20200104 </dev/null >/dev/null 2>&1; then
	fail "non-interactive edit succeeded"
fi
assert_no_file "$test_project/src/2020/01/04.md"

for invalid_date in 20200230 19991231 29991231; do
	if "$test_project/nisshi.sh" touch "$invalid_date" >/dev/null 2>&1; then
		fail "invalid date was accepted: $invalid_date"
	fi
done

make -C "$test_project" >/dev/null
assert_file "$test_project/site/2020/01/02.html"
assert_file "$test_project/site/2020/01/03.html"
assert_contains "$test_project/site/index.md" "[2 (木)](2020/01/02.html)"
assert_contains "$test_project/site/index.md" "[3 (金)](2020/01/03.html)"

sleep 1
touch "$test_project/src/2020/01/02.md"
build_plan="$(make -C "$test_project" -n)"
case "$build_plan" in
	*"site/2020/01/02.html"*) ;;
	*) fail "changed Markdown was not scheduled for rebuild" ;;
esac
case "$build_plan" in
	*"site/2020/01/03.html"*) fail "unchanged Markdown was scheduled for rebuild" ;;
	*) ;;
esac
make -C "$test_project" >/dev/null

css_marker="--nisshi-test-marker: 12345;"
sleep 1
printf '\nbody { %s }\n' "$css_marker" >> "$test_project/assets/pandoc.css"
make -C "$test_project" >/dev/null
assert_contains "$test_project/site/2020/01/02.html" "$css_marker"
assert_contains "$test_project/site/2020/01/03.html" "$css_marker"
assert_contains "$test_project/site/index.html" "$css_marker"

sleep 1
touch "$test_project/Makefile"
build_plan="$(make -C "$test_project" -n)"
case "$build_plan" in
	*"site/2020/01/02.html"*"site/2020/01/03.html"*"site/index.html"*) ;;
	*) fail "Makefile change did not schedule all HTML for rebuild" ;;
esac
make -C "$test_project" >/dev/null

rm "$test_project/src/2020/01/02.md"
make -C "$test_project" >/dev/null
assert_file "$test_project/site/2020/01/02.html"
assert_contains "$test_project/site/index.md" "2020/01/02.html"

make -C "$test_project" clean >/dev/null
make -C "$test_project" >/dev/null
assert_no_file "$test_project/site/2020/01/02.html"
assert_not_contains "$test_project/site/index.md" "2020/01/02.html"
assert_contains "$test_project/site/index.md" "2020/01/03.html"

echo "All tests passed"
