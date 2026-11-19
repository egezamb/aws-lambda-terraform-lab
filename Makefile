TF ?= terraform
PYTHON ?= python3

.PHONY: check init fmt validate test pytest lint security
# The checks CI runs, with no AWS account.
check:
	$(MAKE) init
	$(MAKE) fmt validate test pytest

init:
	$(TF) init -backend=false -input=false

fmt:
	$(TF) fmt -check -recursive

validate:
	$(TF) validate -no-color

test:
	$(TF) test -no-color

pytest:
	$(PYTHON) -m pytest -q tests

# Needs tflint and ruff installed.
lint:
	tflint --init
	tflint --format compact
	ruff check lambda tests

# Needs trivy installed.
security:
	trivy config --skip-check-update --severity HIGH,CRITICAL --exit-code 1 .
