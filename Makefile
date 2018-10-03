##########################
# Constants
PYEXEC ?= python3
MAKE_CMD=$(MAKE) --no-print-directory

PACKAGE = $(shell $(SETUP) --name)
VERSION = $(shell $(SETUP) --version)
MODULE_DIR = $${PWD\#\#*/}
CODE_ROOT = shraklor
PKG_CONFIG_PATH ?= /usr/local/lib/python3.7/site-packages/pkgconfig
SETUP=PKG_CONFIG_PATH="$(PKG_CONFIG_PATH)" $(PYEXEC) setup.py -v
SETUP_COMMON_ARGS := \
		--build-temp .build \
		--build-lib .build
VIRT_ENV=.${MODULE_DIR}

DISTRIBUTION := unstable

MASTER_BRANCH := master
DOC_BRANCH := gh_pages

TEST_PATH := tests/
DOCSDIR := $(CURDIR)/.docs
DOCSSOURCEDIR := $(DOCSDIR)/source
DOCSBUILDDIR := $(DOCSDIR)/build
HTMLDIR := $(DOCSBUILDDIR)/html
REQUIREMENTS=./requirements.txt
TEST_REQUIREMENTS=./test-requirements.txt
ERROR_REPORT=$(CURDIR)/.make-command.txt

# COLORS
RED=\033[0;31m
YELLOW=\033[1;33m
GREEN=\033[0;32m
NOSTYLE=\033[0m
DONE=${GREEN}Done${NOSTYLE}
ERROR=${RED}Error: %s${NOSTYLE}
WARN=${YELLOW}%s${NOSTYLE}
ABORT=Aborting

.DEFAULT_GOAL := .help


##########################
# Functions
define clean_docs
		(mv ${DOCSSOURCEDIR}/index.rst ${DOCSSOURCEDIR}/index.rst.tmp && \
				(rm ${DOCSSOURCEDIR}/*.rst || :) && \
				mv ${DOCSSOURCEDIR}/index.rst.tmp ${DOCSSOURCEDIR}/index.rst)
endef


define extract_url_module
	$(shell echo ${1} | sed 's/\.git//g' | sed 's/.*[\/:].*\/\([^\/]*\)/\1/g' )	
endef


define invenv
	$(shell ${PYEXEC} -c 'import sys; print("1" if sys.prefix != sys.base_prefix else "0")')
endef

define install_prompt
		[ "${1}" == "1" ] || \
			(printf "${WARNING}\n" "You are not in a virtual environment, activate the environment and try again" && \
			printf "${ABORT}!\n" && false)
endef

define to_lower
		$(shell echo ${1} | tr '[:upper:]' '[:lower:]')
endef


define verify_tool
		(which "${1}" > /dev/null 2>&1 || \
				(printf "${ERROR}\n" "Cannot find '${1}' in current PATH" && false))
endef




##############################
# Endpoints
.PHONY: clean
clean: clean-docs
ifneq ($(CLEAN), true)
		@printf "Are you sure you want to clean your virtual environment? [y/n]" && \
				read ANSWER && \
				([ "$${ANSWER}" == "y" ] || (printf "${ABORT}!\n" && false))
endif
	@([ -d "${PACKAGE}.egg-info" ]  && rm -rf "${PACKAGE}.egg-info") || :
	@([ -d ".pytest_cache" ]  && rm -rf ".pytest_cache") || :
	@([ -f ".coverage" ]  && rm -f ".coverage") || :
	@([ -d "__pycache__" ]  && rm -rf "__pycache__") || :
	@([ -d "shraklor/__pycache__" ]  && rm -rf "shraklor/__pycache__") || :
	$(eval module_dir=$(call to_lower,${MODULE_DIR}))
	@([ -d "shraklor/${module_dir}/__pycache__" ]  && rm -rf "shraklor/${module_dir}/__pycache__") || :


##################################
.PHONY: clean-docs
clean-docs: clear-log
	@${MAKE_CMD} -C ${DOCSDIR} clean


##################################
.PHONY: clear-log
clear-log:
	@[ ${MAKELEVEL} != 0 ] || : > ${ERROR_REPORT}


##################################
.PHONY: coverage
coverage: clear-log
	$(PYEXEC) -m pytest $(EXTRA_PYTEST_ARGS) --cov=$(PACKAGE) --cov-report term-missing:skip-covered $(TEST_PATH)


##################################
.PHONY: docs
docs: clean-docs
	@${MAKE_CMD} -C ${DOCSDIR} html


##################################
.PHONY: docs-push
docs-push: clear-log
	$(eval branch=$(shell (git_branch=$$(git branch | grep "*" | sed 's/*\ \(.*\)/\1/g') && \
        [ $$git_branch != "" ] && echo $$git_branch) || \
        echo master))
	$(eval GIT_REMOTE := $(shell git config --get remote.upstream.url))
	$(eval COMMIT_HASH := $(shell git rev-parse HEAD))


	@[ "${branch}" == "${MASTER_BRANCH}" ] || \
		(printf "Do you want to create documentation for the master branch (m) or current branch (c)? [m/c] " && \
		read ans && \
		(([ "$${ans}" == "m" ] && git checkout ${MASTER_BRANCH} >> ${ERROROUT}) || \
		([ "$${ans}" == "c" ] || (printf "Invalid selection... ${ABORT}!\n" && false))))

	@printf "Building documentation ..."
	@${MAKE_CMD} docs >> ${ERROROUT} 2>&1
	@printf "\nDocumentation ready, push to $(GIT_REMOTE)? [y/n] " && read ans && \
		([ "$${ans}" == "y" ] || (${MAKE_CMD} docs-clean >> ${ERROROUT} && \
		echo "${ABORT}!" && false))

	@touch $(HTMLDIR)/.nojekyll
	@git init $(HTMLDIR) >> ${ERROROUT}
	@GIT_DIR=$(HTMLDIR)/.git GIT_WORK_TREE=$(HTMLDIR) git add -A >> ${ERROROUT}
	@GIT_DIR=$(HTMLDIR)/.git git commit -m "Documentation for commit $(COMMIT_HASH)" --no-verify >> ${ERROROUT}
	@GIT_DIR=$(HTMLDIR)/.git git push $(GIT_REMOTE) HEAD:gh-pages --force >> ${ERROROUT}
	@${MAKE_CMD} docs-clean >> ${ERROROUT}

	$(eval new_branch=$(shell (git_branch=$$(git branch | grep "*" | sed 's/*\ \(.*\)/\1/g') && \
        [ $$git_branch != "" ] && echo $$git_branch) || \
        echo master))

	@([ "${branch}" != "${MASTER_BRANCH}" ] && [ "${new_branch}" == "${MASTER_BRANCH}" ] && \
		git checkout ${branch} >> ${ERROROUT} 2>&1) || :


######################################
.PHONY: install
install: install-requirements
	${PYEXEC} -m pip install .

######################################
.PHONY: install-editable
install-editable: install-requirements
	${PYEXEC} -m pip install -e .


######################################
.PHONY: install-requirements
install-requirements: clear-log
ifneq ($(FORCE),true)
	$(eval in_virt=$(call invenv))
	@$(call install_prompt,${in_virt})
endif
	${PYEXEC} -m pip install --upgrade pip
	${PYEXEC} -m pip install -r ${REQUIREMENTS}


######################################
.PHONY: install-test
install-test: install-test-requirements
	${PYEXEC} -m pip install .


######################################
.PHONY: install-test-editable
install-test-editable: install-test-requirements
	${PYEXEC} -m pip install -e .


######################################
.PHONY: install-test-requirements
install-test-requirements: clear-log
ifneq ($(FORCE),true)
	$(eval in_virt=$(call invenv))
	@$(call install_prompt,${in_virt})
endif
	${PYEXEC} -m pip install --upgrade pip
	${PYEXEC} -m pip install -r ${REQUIREMENTS} -r ${TEST_REQUIREMENTS} .


######################################
.PHONY: lint
lint: clear-log
	@$(PYEXEC) -m pylint ${CODE_ROOT}


######################################
.PHONY: list
list: clear-log
	@${MAKE_CMD} -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>> ${ERROROUT} | awk -v RS= -F: \
        '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | \
        egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs


######################################
# Run all tests
.PHONY: test
test: test-unit


######################################
.PHONY: test-unit
# Run unit tests
test-unit: clear-log
	$(PYEXEC) -m pytest -v $(EXTRA_PYTEST_ARGS) $(TEST_PATH)




