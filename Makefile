.PHONY: build_dummy_translations clean compile_translations coverage detect_changed_source_translations docs dummy_translations extract_translations help pull_translations push_translations quality requirements selfcheck test test-all upgrade validate validate_translations

.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

clean: ## remove generated byte code, coverage reports, and build artifacts
	find . -name '__pycache__' -exec rm -rf {} +
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	coverage erase
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

coverage: clean ## generate and view HTML coverage report
	pytest --cov-report html
	$(BROWSER) htmlcov/index.html

COMMON_CONSTRAINTS_TXT=requirements/common_constraints.txt
.PHONY: $(COMMON_CONSTRAINTS_TXT)
$(COMMON_CONSTRAINTS_TXT):
	wget -O "$(@)" https://raw.githubusercontent.com/edx/edx-lint/master/edx_lint/files/common_constraints.txt || touch "$(@)"

upgrade: export CUSTOM_COMPILE_COMMAND=make upgrade
upgrade: $(COMMON_CONSTRAINTS_TXT)
	## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	pip install -qr requirements/pip-tools.txt
	pip-compile --upgrade --rebuild --allow-unsafe -o requirements/pip.txt requirements/pip.in
	pip-compile --upgrade --rebuild -o requirements/pip-tools.txt requirements/pip-tools.in
	pip install -qr requirements/pip.txt
	pip install -qr requirements/pip-tools.txt
	pip-compile --upgrade -o requirements/dev.txt requirements/base.in requirements/dev.in requirements/quality.in requirements/test.in requirements/travis.in
	pip-compile --upgrade -o requirements/quality.txt requirements/base.in requirements/quality.in requirements/test.in
	pip-compile --upgrade -o requirements/test.txt requirements/base.in requirements/test.in
	pip-compile --upgrade -o requirements/travis.txt requirements/travis.in
	pip-compile --upgrade -o requirements/ci.txt requirements/ci.in
	# Let tox control the Django version for tests
	grep -e "^django==" requirements/test.txt > requirements/django.txt
	sed '/^django==/d' requirements/test.txt > requirements/test.tmp
	mv requirements/test.tmp requirements/test.txt

quality: ## check coding style with pycodestyle and pylint
	tox -e quality

requirements: ## install development environment requirements
	pip install -qr requirements/dev.txt --exists-action w
	pip-sync requirements/dev.txt requirements/private.*

test: clean ## run tests in the current virtualenv
	mkdir -p var
	pip install -e .
	pytest

diff_cover: test ## find diff lines that need test coverage
	diff-cover coverage.xml

test-all: ## run tests on every supported Python/Django combination
	tox -e quality
	tox

validate: quality test validate_translations ## run tests and quality checks

## Localization targets
extract_translations: ## extract strings to be translated, outputting .po files
	rm -rf docs/_build

	# Extract Python and Django template strings
	mkdir -p locale/en/LC_MESSAGES/
	rm -f locale/en/LC_MESSAGES/{django,text}.po
	django-admin makemessages -l en -v1 -d django
	mv locale/en/LC_MESSAGES/django.po locale/en/LC_MESSAGES/text.po

compile_translations: ## compile translation files, outputting .mo files for each supported language
	i18n_tool generate
	make clean

detect_changed_source_translations: ## Determines if the source translation files are up-to-date, otherwise exit with a non-zero code.
	i18n_tool changed

pull_translations: ## pull translations from Transifex
	i18n_tool transifex pull
	make compile_translations

push_translations: extract_translations ## push source translation files (.po) to Transifex
	i18n_tool transifex push

dummy_translations: ## generate dummy translation (.po) files
	i18n_tool dummy

build_dummy_translations: extract_translations dummy_translations compile_translations ## generate and compile dummy translation files

validate_translations: build_dummy_translations detect_changed_source_translations ## validate translations

selfcheck: ## check that the Makefile is well-formed
	@echo "The Makefile is well-formed."
