# Makefile - build & run automation for riscv-log-analyzer

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

ANALYZE := ./scripts/analyze.sh
LOGS    := $(wildcard test_data/*.log)
REPORTS := $(patsubst test_data/%.log,output/%.txt,$(LOGS))

.PHONY: all test report clean help setup

all: $(REPORTS) ## Run the analyzer on all test log files
	@cat $(REPORTS)

# Pattern rule: build output/<name>.txt from test_data/<name>.log
# ($< = first prerequisite, $@ = target). Exit code 1 (= failing tests) is allowed.
output/%.txt: test_data/%.log $(ANALYZE)
	@$(ANALYZE) $< --output $@ || [ $$? -eq 1 ]
	@echo "Generated $@"

# $(call check_log,<logfile>,<expected exit code>,<expected text in output>)
define check_log
	@rc=0; out=$$($(ANALYZE) $(1)) || rc=$$?; \
	if [ "$$rc" -eq $(2) ] && echo "$$out" | grep -q "$(3)"; then \
	    echo "  [PASS] $(1)"; \
	else \
	    echo "  [FAIL] $(1) (exit code $$rc, expected $(2))"; exit 1; \
	fi
endef

test: ## Run the analyzer on each test log and verify the output
	@echo "Running tests..."
	$(call check_log,test_data/sample_pass.log,0,Verdict: PASS)
	$(call check_log,test_data/sample_fail.log,1,Verdict: FAIL)
	$(call check_log,test_data/sample_sim.log,1,rv32i-sw)
	@echo "All tests passed."

report: ## Generate reports and a summary in output/
	@./scripts/generate_report.sh $(LOGS) > /dev/null
	@echo "Summary written to output/summary.txt"

clean: ## Remove all generated output files
	rm -f output/*.txt output/*.csv output/*.html
	@echo "Cleaned output/"

setup: ## Check that required tools are installed
	@./scripts/setup_env.sh

help: ## Print all available targets
	@echo "Available targets:"
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | sed -E 's/^([a-z]+):.*## (.*)/  make \1\t\2/'
