#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<-FIN >&2
	$(basename "$0") >>> write and read nisshi
	Usage   : $(basename "$0") [action] [YYYYMMDD]
	Actions : edit (default), touch, get, getpath, make, open
	FIN
}

script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
	script_dir="$(cd -P -- "$(dirname -- "$script_path")" && pwd)"
	script_path="$(readlink "$script_path")"
	case "$script_path" in
		/*) ;;
		*) script_path="$script_dir/$script_path" ;;
	esac
done
apld="$(cd -P -- "$(dirname -- "$script_path")" && pwd)"
mdd="$apld/src"
read -r -a editor_command <<< "${EDITOR:-vim}"

dateopt="false"
action="edit"

if [ "$#" -ge 1 ]; then
	case "$1" in
		get|open|getpath|touch|make|edit)
			action="$1"
			shift 1
			;;
		-h|--help|help)
			usage
			exit 0
			;;
		[0-9]*)
			# through
			;;
		*)
			echo "Error($LINENO)[$(basename "$0")] : unknown action '$1'" >&2
			usage
			exit 1
			;;
	esac
fi

if [ "$#" -gt 1 ]; then
	echo "Error($LINENO)[$(basename "$0")] : too many arguments" >&2
	usage
	exit 1
fi

validate_date() {
	local input="$1"
	local normalized

	if date --version &>/dev/null; then
		normalized="$(date -d "$input" "+%Y%m%d" 2>/dev/null)" || return 1
	else
		normalized="$(date -j -f "%Y%m%d" "$input" "+%Y%m%d" 2>/dev/null)" || return 1
	fi
	[ "$normalized" = "$input" ]
}

if [ "$#" -ge 1 ]; then
	today="$(date '+%Y%m%d')"
	if ! [[ "$1" =~ ^[0-9]{8}$ ]]; then
		echo "Error($LINENO)[$(basename "$0")] : invalid date '$1'" >&2
		exit 1
	elif ! validate_date "$1"; then
		echo "Error($LINENO)[$(basename "$0")] : invalid date '$1'" >&2
		exit 1
	elif ! [ "$1" -le "$today" ]; then
		echo "Error($LINENO)[$(basename "$0")] : invalid date 'future'" >&2
		exit 1
	elif ! [ "$1" -ge "20000101" ]; then
		echo "Error($LINENO)[$(basename "$0")] : invalid date 'too past'" >&2
		exit 1
	fi
	yyyy="${1:0:4}"
	mm="${1:4:2}"
	day="${1:6:2}"
	dateopt="true"
else
	yyyy="$(date '+%Y')"
	mm="$(date '+%m')"
	day="$(date '+%d')"
fi

month="$yyyy/$mm"
file="$mdd/$month/$day.md"

createfile_if_not_exist() {
	mkdir -p "$mdd/$month"
	if [ ! -s "$file" ]; then
		cat <<-FIN > "$file"
		---
		title: ${yyyy}年 ${mm}月 ${day}日
		---

		## 作業内容など

		FIN
	fi
}
make_html() {
	cd "$1" && make
}
open_html() {
	case "$(uname -s)" in
		Darwin)
			open "$1"
			;;
		Linux)
			if ! command -v xdg-open >/dev/null 2>&1; then
				echo "Error($LINENO)[$(basename "$0")] : xdg-open is required" >&2
				return 1
			fi
			xdg-open "$1"
			;;
		*)
			echo "Error($LINENO)[$(basename "$0")] : unsupported operating system" >&2
			return 1
			;;
	esac
}

case "$action" in
	edit)
		if [ ! -t 0 ] || [ ! -t 1 ]; then
			echo "Error($LINENO)[$(basename "$0")] : edit requires an interactive terminal" >&2
			exit 1
		fi
		createfile_if_not_exist
		"${editor_command[@]}" "$file"
		make_html "$apld"
		;;
	make)
		make_html "$apld"
		;;
	open)
		if [ "$dateopt" == "true" ]; then
			open_html "$apld/site/$yyyy/$mm/$day.html"
		else
			open_html "$apld/site/index.html"
		fi
		;;
	touch)
		createfile_if_not_exist
		;;
	get)
		cat "$file"
		;;
	getpath)
		echo "$file"
		;;
	*)
		echo "Error($LINENO)[$(basename "$0")] : not-implemented action '$action'" >&2
		exit 1
		;;
esac

exit 0
