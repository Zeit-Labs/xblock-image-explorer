.PHONY: clean compile_translations dummy_translations \
	extract_translations dummy_translations help

.DEFAULT_GOAL := help

WORKING_DIR := image_explorer
EXTRACT_DIR := $(WORKING_DIR)/conf/locale/en/LC_MESSAGES
EXTRACTED_DJANGO_PARTIAL := $(EXTRACT_DIR)/django-partial.po
EXTRACTED_DJANGOJS_PARTIAL := $(EXTRACT_DIR)/djangojs-partial.po
EXTRACTED_DJANGO := $(EXTRACT_DIR)/django.po

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

clean: ## remove generated byte code, coverage reports, and build artifacts
	find . -name '__pycache__' -exec rm -rf {} +
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

piptools: ## install pinned version of pip-compile and pip-sync
	pip install -r requirements/pip.txt
	pip install -r requirements/pip-tools.txt

requirements: piptools  ## install test requirements locally
	pip-sync requirements/ci.txt

requirements_python: piptools  ## install all requirements locally
	pip-sync requirements/base.txt requirements/ci.txt requirements/test.txt requirements/private.*

# Define PIP_COMPILE_OPTS=-v to get more information during make upgrade.
PIP_COMPILE = pip-compile --upgrade $(PIP_COMPILE_OPTS)

upgrade: export CUSTOM_COMPILE_COMMAND=make upgrade
upgrade: ## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	pip install -qr requirements/pip-tools.txt
	# Make sure to compile files after any other files they include!
	$(PIP_COMPILE) --allow-unsafe -o requirements/pip.txt requirements/pip.in
	$(PIP_COMPILE) -o requirements/pip-tools.txt requirements/pip-tools.in
	pip install -qr requirements/pip.txt
	pip install -qr requirements/pip-tools.txt
	$(PIP_COMPILE) -o requirements/base.txt requirements/base.in
	$(PIP_COMPILE) -o requirements/test.txt requirements/test.in
	$(PIP_COMPILE) -o requirements/ci.txt requirements/ci.in
	sed -i '/^[dD]jango==/d' requirements/test.txt

## Localization targets

extract_translations: ## extract strings to be translated, outputting .po files
	cd $(WORKING_DIR) && i18n_tool extract
	mv $(EXTRACTED_DJANGO_PARTIAL) $(EXTRACTED_DJANGO)
	# Safely concatenate djangojs if it exists
	( test -f $(EXTRACTED_DJANGOJS_PARTIAL) && \
	  msgcat $(EXTRACTED_DJANGO) $(EXTRACTED_DJANGOJS_PARTIAL) -o $(EXTRACTED_DJANGO) \
	) || ! test -f $(EXTRACTED_DJANGOJS_PARTIAL)
	rm -rf $(EXTRACTED_DJANGOJS_PARTIAL)
	sed -i'' -e 's/nplurals=INTEGER/nplurals=2/' $(EXTRACTED_DJANGO)
	sed -i'' -e 's/plural=EXPRESSION/plural=\(n != 1\)/' $(EXTRACTED_DJANGO)

compile_translations: ## compile translation files, outputting .mo files for each supported language
	cd $(WORKING_DIR) && i18n_tool generate

detect_changed_source_translations:
	cd $(WORKING_DIR) && i18n_tool changed

dummy_translations: ## generate dummy translation (.po) files
	cd $(WORKING_DIR) && i18n_tool dummy

build_dummy_translations: dummy_translations compile_translations ## generate and compile dummy translation files

validate_translations: build_dummy_translations detect_changed_source_translations ## validate translations
