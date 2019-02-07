# Makefile includes for song directories
#

# Songs is the web directory; each song is in an individual subdirectory
#   [song]/lyrics.{html,pdf,txt} are built from ../Lyrics*/[song].flk
#   this needs to be fixed eventually.

# Utility programs:
TEXDIR	  = $(TOOLDIR)/TeX
FLKTRAN   = $(TEXDIR)/flktran.pl
INDEX     = $(TEXDIR)/index.pl
TRACKINFO = $(TOOLDIR)/music/TrackInfo.pl
SONGINFO  = $(TOOLDIR)/music/songinfo
SORT_BY_TITLE = $(TEXDIR)/sort-by-title
MUSTACHE  = $(shell which mustache)

# These are the tags for which we can put lyrics on the web.  This can be overridden
# in the local .config.make, e.g. to add specific songwriter tags.
WEB_OK_TAGS = web-ok mine ours pd cc

# These are the tags that indicate that it's not ok to put up lyrics, even if they have
# one of the tags in WEB_OK_TAGS.  The rej and wip tags are included for completeness;
# songs that have them don't normally have directories made for them.
NOT_OK_TAGS = not-ok rej wip

# Directories containing lyrics (virtual path for dependencies):
LPATH := $(filter-out %WIP, $(wildcard $(BASEREL)Lyrics*))
VPATH = $(LPATH)

# We need a list of lyrics that includes the path information.  Instead of relying
# on the makefiles in the various lyrics directories, we go direct.  Files containing
# "--" are versions in different keys, and are meant to be printed individually when
# someone is performing with an instrument that can't be capoed.
#
# ASONGS is just the song files sorted by pathname
#   It's almost impossible to write a glob that rejects template files at this point,
#   but they get filtered out in ALLSONGS because they have an empty song title.
ASONGS := $(shell for d in $(LPATH); do ls $$d/*.flk; done)

# REJECT = work in progress and other songs we don't want on the web at all.
#
REJECT := $(shell [ -z "$(ASONGS)" ] || grep -ilEe '^\\tags.*\W(wip|rej)\W' $(ASONGS))

# ALLSONGS is the list of files sorted by title, which is more useful
ALLSONGS := $(shell $(SORT_BY_TITLE)  $(filter-out $(REJECT),$(ASONGS)))

# Directory names:
#	DIRNAMES is the list of all song directories, sorted by title.  (We sort
#	by title because eventually we'll want to build indices and such.)
#	It would be better if we could use filter-out, but it doesn't handle regexps
#	Similarly, we need the loop because grep needs each name on a separate line.
DIRNAMES := $(shell for f in $(subst .flk,,$(notdir $(ALLSONGS))); do echo $$f; done \
		    | grep -v -e .orig -e --)

# Lists.  Just the ones we actually need
ALLPDF   = $(patsubst %,%/lyrics.pdf,$(DIRNAMES))
ALLHTML  = $(patsubst %,%/lyrics.html,$(DIRNAMES))
ALLTEXT  = $(patsubst %,%/lyrics.txt,$(DIRNAMES)) \
	   $(patsubst %,%/lyrics.chords.txt,$(DIRNAMES))

# Indices: 
# 	0Index.html is the index web page, 0IndexTable.html is just the
#	 <table> element, for use in template replacement.
#	0IndexShort.html is the raw list of names linked to subdirs
#	0IndexLong.html is the long table with descriptions
WEBINDICES = 0Index.html 0IndexTable.html 0IndexShort.html
SUBDIR_INDICES =  $(patsubst %,%/index.html, $(DIRNAMES))

# At some point we can add 1Index*, after we add subdir indices that can handle
# directories without visible lyrics.

reportVars += LPATH ASONGS ALLSONGS DIRNAMES WEB_OK_TAGS MUSTACHE

########################################################################
###
### Rules:
###

# Rules to make song subdirectories and their contents

%: | %.flk
	mkdir -p $@

# lyrics.pdf
#	It would be better if we could make foo/lyrics.pdf directly, but
#	there's no good way to do that because latex doesn't have a way
#	to specify the output file, just the output directory.
#
#	We also can't make %/%.pdf, because make can't handle rules with
#	multiple wildcards on the left.
#	
%/lyrics.pdf: %.dvi | %
	dvipdf $< $@

# %.dvi:  Intermediate stage in making %/lyrics.pdf
#	We want to do the build in the Lyrics directory rather than here
#	because there may be multiple lyrics directories in the search path,
#	and we want to use whatever local styles they have, including
#	singer annotations (zinger.sty).
#
#	An alternative would be to put the lyrics directory in the
#	search path, which would allow us to override the songbook
#	style here if we wanted to.  See lyrics.make for the rule.
#
%.dvi:	%.flk
	d=`pwd`; cd `dirname $<`; $(MAKE) $$d/$*.dvi DESTDIR=$$d

%/lyrics.html: %.flk | %
	WEBSITE=$(WEBSITE) WEBDIR=$(MYNAME) $(FLKTRAN) -t -b $< $@

%/lyrics.txt: %.flk | %
	WEBSITE=$(WEBSITE) WEBDIR=$(MYNAME) $(FLKTRAN) $< $@

%/lyrics.chords.txt: %.flk | %
	WEBSITE=$(WEBSITE) WEBDIR=$(MYNAME) $(FLKTRAN) -c $< $@


# We can generate several types of metadata.
#	metadata.yml is an input to the mustache template engine
# 	metadata.sh and metadata.make can be included in shell scripts and makefiles;
#	that may not be necessary at this point, but they can be used as alternative
#	templating engines in a pinch.

%/metadata.sh: %.flk $(SONGINFO) | %
	$(SONGINFO) --format=shell --ok='$(WEB_OK_TAGS)' $< > $@

%/metadata.yml: %.flk $(SONGINFO) | %
	$(SONGINFO) --format=yaml --ok='$(WEB_OK_TAGS)' $< > $@

%/metadata.make: %.flk $(SONGINFO) | %
	$(SONGINFO) --format=make --ok='$(WEB_OK_TAGS)' $< > $@

# The index.html files depend on the corresponding metadata.
#	Note that if we don't explicitly make the metadata, it will be treated as an
#	intermediate file and deleted after making index.html.
#
#	On the other hand, we _do_ want to delete the symlink to the template.
#	It's there because paths to partials are resolved relative to the template.
#
#	At some point we might want to try mo: Mustache templates in pure bash
#       https://github.com/tests-always-included/mo
#
#	Note that we are no longer using server-side includes here.  Currently
#	they _are_ used elsewhere in the site, mainly for footers.  Also note
#	that in order for this to work, footers etc. have to be in /site, which
#	must be a sibling of /Songs.
#
ifneq ($(MUSTACHE),)
%/index.html: %/metadata.yml 1subdir-index.mustache
	cd $(dir $@);  ln -sf ../1subdir-index.mustache; 			\
	    $(MUSTACHE) metadata.yml 1subdir-index.mustache > index.html; 	\
	    rm ./1subdir-index.mustache
else
%/index.html:
	touch $@
endif


# Ogg and mp3 files.  
#	They have no dependencies to prevent their being constantly rebuilt.
#	It might be better to make the mp3s depend on the oggs.
%.ogg: 
	oggenc -Q -o $@ $(shell $(TRACKINFO) --ogg  $*)
%.mp3: 
	sox $(shell $(TRACKINFO) format=files $*) -w -t wav - | \
	  lame -b 64 -S $(shell $(TRACKINFO) $(SONGLIST_FLAGS)  \
	   --mp3 $*) $@

AUDIO_LINKS = $(shell for f in */*.ogg; do \
		echo `dirname $$f`/audio-links.html; done | uniq)
all::	$(AUDIO_LINKS)

## If a subdirectory contains audio files, it needs an audio-links.html file
#	If there are only ogg and mp3 files with names that match the directory,
#	things are simple.  Otherwise somebody is going to have to do some editing.
#
#	This is a single-colon rule with no dependencies, so it will only be built
#	if it does not already exist.  Once it's there you can edit it to add
#	additional links or text.
#
%/audio-links.html:
	d=$(subst /,,$(dir $@)); \
	  echo "<h3 id='Recordings'>Recordings:</h3>" 				 > $@; \
	  echo "<p class='recording'>"						>> $@; \
	  echo "    <a href='$$d.ogg'>[ogg]</a> <a href='$$d.mp3'>[mp3]</a>"	>> $@; \
	  echo "    <audio controls>" 						>> $@; \
	  echo "         <source src='$$d.ogg' type='audio/ogg'>"		>> $@; \
	  echo "         <source src='$$d.mp3' type='audio/mp3'>"		>> $@; \
	  echo "    </audio>"	 						>> $@; \
	  echo "</p>"	 							>> $@; \
	  echo "<hr />"								>> $@


########################################################################
###
### Targets
###

all::	$(DIRNAMES) $(ALLPDF) metadata $(ALLHTML) $(ALLTEXT)

.PHONY: metadata
metadata::	$(patsubst %,%/metadata.yml, $(DIRNAMES))
metadata::	$(patsubst %,%/metadata.sh, $(DIRNAMES))


### Showing and hiding lyrics:
#
#	For now, we're simply symlinking lyrics.html in any web-visible
#	directory, and unlinking it (showing any unfortunate user an
#	error if they try to see it) for non-web songs.
#
#	Eventually the plan is for index.html to come from a template and
#	do server-side includes for header, notes, audio files, and
#	lyrics.  That will allow us to show pages for all songs in our
#	repertoire.
#
#	In either case, we do this in a loop, so that if the status of
#	a song changes we do the right thing.

.PHONY: subdir-indices

subdir-indices: $(SUBDIR_INDICES)

ifneq ($(MUSTACHE),)
## If we have the templating engine it's safe to rebuild */index.html
all:: subdir-indices
endif

### Lists:

list-names:
	@echo $(DIRNAMES)
list-dirs: 
	@echo $(DIRNAMES)
list-allsongs: 
	@echo $(ALLSONGS)
list-websongs: 
	@echo $(WEBSONGS)


### Songbook:  Just my stuff and public domain.  
#	Note that the Songbook doesn't have a proper index -- use the 
#	public HTML index file for that.

# Songbook: a songbook with just the lyrics and chords, not the notes
songbook: $(PS) 
	@for f in $(PS) ; do psselect -p1 $$f | lpr; done 

# Longbook: a songbook that includes the extra pages of notes
longbook: $(PS) 
	@for f in $(PS) ; do lpr $$f ; done 

### Zongbook:  everything, including third-party, in a single file

# "zongbook.ps" -- everything in a single .ps file, with index

zongbook.dvi: song.sty zongbook.sty
zongbook: zongbook.ps


### Cleanup:

texclean::
	-rm *.aux *.log *.toc *.dvi

clean::
	-rm *.CKP *.ln *.BAK *.bak *.o core errs ,* *~ *.a 	\
		.emacs_* tags TAGS MakeOut *.odf *_ins.h	\
		*.aux *.log *.toc *.dvi *.lj *.ps  		\
		$(WEBINDICES) $(INDICES)
	-rm -f $(ALLHTML)
	-rm -f $(ALLTEXT)

pubclean::
	-rm -f $(ALLHTML)
	-rm -f $(ALLTEXT) $(WEBINDICES) $(INDICES)

htmlclean::
	-rm -f $(ALLHTML)

### Setup:


### Website indices:

# FIXME: At the moment neither $(INDEX) and $(TRACKINFO) is able to handle
# multiple lyrics directories. 

# We used to generate complete HTML files, but that's not nearly versatile
# enough.  What we do now is generate HTML fragments that get included in
# the real index.html and other pages.

# Also, we now generate the indices from the directory listing, rather than
# trying to generate lists in the lyrics directory.  That gives us better
# control over what's included.

WEBINDICES = 0Index.html 0IndexShort.html 0IndexTable.html 0IndexLong.html

.PHONY: webindices 
webindices: $(WEBINDICES)

# indices currently broken
all:: webindices

# 0Index.html is a kludge -- don't link to it!
#	The right thing to do is make a page called, e.g., SongIndex.html that #includes
#	either 0IndexTable or 0IndexLong
0Index.html: $(ALLSONGS) $(DIRNAMES) $(INDEX) $(TOOLDIR)/music/songs.make
	@echo building $@ from WEBLYRICS
	@echo '<html>' 					>  $@
	@echo '<head>'					>> $@
	@echo '<title>Song Index</title>'		>> $@
	@echo '<link href="../site/style.css" rel="stylesheet" type="text/css">' >> $@
	@echo '</head><body>'				>> $@
	@echo '<nav><a href="/">[home]</a>'		>> $@
	@echo '  / <a href="../Songs">Songs</a>'	>> $@
	@echo '  / <a href="./">Song Index</a></nav>'	>> $@
	@$(INDEX) -t -h $(ALLSONGS)			>> $@
	@echo '<h5>Last update: ' `date` '</h5>'	>> $@
	@echo '</body>'					>> $@
	@echo '</html>' 				>> $@

0IndexTable.html: $(INDEX)
	@echo building $@ from WEBLYRICS
	@echo '<!-- begin $@ -->'			>  $@
	@$(INDEX) -t -h $(ALLSONGS)			>> $@
	@echo '<!-- end $@ -->'				>> $@

0IndexShort.html: 
	@echo building $@ from directory listing:
	@echo '<!-- begin $@ -->'			>  $@
	@for f in `echo $(DIRNAMES) | tr ' ' "\n" | sort | uniq`; do \
		echo '<a href="'$$f/'">'$$f'</a>' >> $@; \
	done
	@echo '<!-- end $@ -->'				>> $@

# Note that TrackInfo might not look at metadata to check whether it should include lyrics
0IndexLong.html: 
	$(TRACKINFO) --long --credits --sound -t format=list.html $(DIRNAMES) > $@
