#!/usr/bin/make  ### make/defines.make -- standard definitions for makefiles

# MFDIR is where the make include files live
MFDIR	= $(TOOLDIR)/make

# Compute relative paths to BASEDIR and TOOLDIR
TOOLREL:= $(shell if [ -e Tools ]; then echo Tools; \
		  else d=""; while [ ! -d $$d/Tools ]; do d=../$$d; done; \
		       echo $${d}Tools; fi)
ifeq ($(TOOLREL),Tools)
      BASEREL:= ./
else
      BASEREL:= $(dir $(TOOLREL))
endif

### Web upload location and excludes:
#	DOTDOT is the path to this directory on $(HOST); it works because
#	/vv is the parent of our whole deployment tree, and ~/vv exists on
#	the web host.  This is not really a good assumption, and fails
#	miserably when deploying from, e.g., a laptop.  Don't do that.
#	Either can be overridden if necessary in the local config.make
#
DOTDOT  := .$(MYDIR)
HOST	 = savitzky@savitzky.net
EXCLUDES = --exclude=Tracks --exclude=Master --exclude=Premaster \
	   --exclude=\*temp --exclude=.audacity\* --exclude=.git
#
###

### Files and Subdirectories:
#	Note that $(SUBDIRS) only includes real directories with a Makefile
#
FILES    = Makefile $(wildcard *.html *.ps *.pdf)
ALLDIRS  := $(shell ls -F | grep / | grep -v CVS | sed s/\\///)
SUBDIRS  := $(shell for d in $(ALLDIRS); do \
	     if [ -e $$d/Makefile -a ! -L $$d ]; then echo $$d; fi; done)

# real (not linked) subdirs containing git repositories.
#    Note that we do not require a Makefile, only .git.

GITDIRS := $(shell for d in $(ALLDIRS); do \
		if [ -d $$d/.git -a ! -L $$d ]; then echo $$d; fi; done)

### Different types of subdirectories.
#   Collection:  capitalized name
#   Item:	 lowercase name -- not always consistent
#   Date:	 digit
#
COLLDIRS := $(shell for d in $(ALLDIRS); do echo $$d | grep ^[A-Z]; done) 
ITEMDIRS := $(shell ls -d $(ALLDIRS) | grep ^[a-z]) 
DATEDIRS := $(shell ls -d $(ALLDIRS) | grep ^[0-9])
#
###

### Paths for date-based file creation
#
DAYPATH   := $(shell date "+%Y/%m/%d")
MONTHPATH := $(shell date "+%Y/%m")
# Other time-based values
TIME	  := $(shell date "+%H%M%S")
TIMESTAMP := $(shell date -u +%Y%m%dT%H%M%SZ)
#
###

### git setup:
#

# Find the git repo, if any.  Note that it can be anywhere between here and 
#	BASEDIR (which, in turn, might not have one)
GIT_REPO := $(shell d=$(MYPATH); 					\
		  while [ ! -d $$d/.git ] && [ ! $$d = $(BASEDIR) ]; do	\
			d=`dirname $$d`;				\
		  done; [ -d $$d/.git ] && echo $$d/.git)

ifdef GIT_REPO
  GIT_COMMIT = $(git log --format=format:%H -n1)

  # The commit when we started make.  We can use this to see whether we made a
  #     new commit as part of the deployment process.
  GIT_INITIAL_COMMIT := $(GIT_COMMIT)

  # deploy/push commit message:
  #	Can be overridden or appended to in config.make
  COMMIT_MSG := from $(shell hostname) $(shell date)
endif
#
###

### site configuration directory:
#	SITEDIR is defined as $(BASEDIR)/site iff it exists.
#	Note the use of wildcard to test for existence.

ifneq ($(wildcard $(BASEDIR)/site)),)
  SITEDIR = $(BASEDIR)/site
  ifneq ($(wildcard $(SITEDIR)/config.make),)
    include $(SITEDIR)/config.make
  endif
endif


