# Makefile
# 使い方:
#   make          # 全HTML生成
#   make clean    # 生成物削除
#   make serve    # ローカル確認 (Python http.server)

PANDOC ?= pandoc
PYTHON ?= python3
PORT ?= 8000
SRC_DIR := src
OUT_DIR := site
CSS_FILE := assets/pandoc.css

# pandoc オプション（必要に応じて調整）
PANDOC_EMBED_OPT := $(shell \
	if $(PANDOC) --help 2>/dev/null | grep -q -- '--embed-resources'; then \
		printf '%s' '--embed-resources'; \
	else \
		printf '%s' '--self-contained'; \
	fi)
PANDOC_OPTS := \
	-s \
	$(PANDOC_EMBED_OPT) \
	-c $(CSS_FILE)

# 変換対象の .md（README と 年/月/日を含む）
MD_FILES := $(sort $(shell if [ -d "$(SRC_DIR)" ]; then find "$(SRC_DIR)" -type f -name '*.md'; fi))
# 出力先の .html（site/ 以下にミラー）
HTML_FILES := $(patsubst $(SRC_DIR)/%.md,$(OUT_DIR)/%.html,$(MD_FILES))

# index
INDEX_MD := $(OUT_DIR)/index.md
INDEX_HTML := $(OUT_DIR)/index.html


.PHONY: all clean index serve test
all: $(HTML_FILES) index

# 出力ディレクトリを作ってから pandoc 変換
$(OUT_DIR)/%.html: $(SRC_DIR)/%.md $(CSS_FILE) Makefile
	@mkdir -p $(dir $@)
	$(PANDOC) $(PANDOC_OPTS) -o $@ $<

# index.md 自動生成
index: $(INDEX_HTML)

$(INDEX_HTML): $(HTML_FILES) $(CSS_FILE) Makefile | $(OUT_DIR)
	@echo "# Journal Index" > $(INDEX_MD)
	@echo "" >> $(INDEX_MD)
	@find $(OUT_DIR) -type f -name '*.html' \
		! -name 'index.html' \
		| sort -r \
		| sed 's|^$(OUT_DIR)/||' \
		| awk -F/ ' \
			BEGIN { \
				split("0 3 2 5 0 3 5 1 4 6 2 4", month_offset, " "); \
				split("日 月 火 水 木 金 土", weekday_name, " "); \
			} \
			{ \
				if ($$1 != prev_year) { \
					if (NR > 1) print ""; \
					print "## " $$1; \
					prev_year = $$1; \
					prev_month = ""; \
				} \
				if ($$2 != prev_month) { \
					print ""; \
					print "### " $$2; \
					prev_month = $$2; \
				} \
				year = $$1 + 0; \
				month = $$2 + 0; \
				day = $$3; \
				sub(/\.html$$/, "", day); \
				weekday_year = year; \
				if (month < 3) weekday_year--; \
				weekday = (weekday_year + int(weekday_year / 4) \
					- int(weekday_year / 100) + int(weekday_year / 400) \
					+ month_offset[month] + day) % 7; \
				printf "- [%d (%s)](%s)\n", \
					day, weekday_name[weekday + 1], $$0; \
			}' >> $(INDEX_MD)
	$(PANDOC) $(PANDOC_OPTS) -o $(INDEX_HTML) $(INDEX_MD)

$(OUT_DIR):
	@mkdir -p "$@"

serve: all
	$(PYTHON) -m http.server "$(PORT)" --bind 127.0.0.1 --directory "$(OUT_DIR)"

test:
	./tests/test.sh

clean:
	$(RM) -r $(OUT_DIR)
