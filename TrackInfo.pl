#!/usr/bin/perl
# $Id: TrackInfo.pl,v 1.4 2007-02-01 14:39:42 steve Exp $
# TrackInfo [options] infile... 
#	<title>extract track info</title>

### Extracts information about a track from song (.flk) files, track 
#	notes, or local (album) notes (with a name like trackname.notes)
#	The local name may have an optional numeric prefix.
#	produces either a TOC file suitable for use in cdrdao, 
#	a set of command-line options for oggenc, or (by default)
#	a simple property list of name=value assignments.

# ===	Need to look for .wav file in . first, then ../Tracks/name
#	Need to look for .flk file first in ., then in ../Songs

### Defaults:
#	Note that the "songwriter" is assumed to be both the lyricist and
#	the composer unless otherwise noted.  
$default_songwriter  = "Steve Savitzky";
$default_performer   = "Steve Savitzky";

$publicSongs = "/Steve_Savitzky/Songs/";
$publicSite  = "http://theStarport.com";


### Look for the songs in the usual places:
#	We do this by assuming that the songlist file is with them.

$songlistFile = "songlist.txt";
$songlistFile .= ".txt" unless $songlistFile =~ /\./;

if ($0 =~ m|^(.*)/[^/]+$|) {
    $cmdDir = $1;
} else {
    $cmdDir = ".";
}

$songDir = $ENV{SONGDIR};
$songDir = "./Songs" unless -d $songDir;
$songDir = "../Songs" unless -d $songDir;
$songDir = "../../Songs" unless -d $songDir;
$songDir = "." unless -d $songDir;

$trackDir = $ENV{TRACKDIR};
$trackDir = "../Tracks" unless -d $trackDir;
$trackDir = "../../Tracks" unless -d $trackDir;
$trackDir = "." unless -d $trackDir;

# === this will have to change eventually ===

if (-f  "$songDir$songlistFile") {
    # everything's cool
} elsif (-f "$root$publicSongs$songlistFile") {
    # we must be on the public site, then.
    $songDir = "$root$publicSongs";
} else {
    # can't find the song directory, so we're hosed anyway.
}

# === needs to come from config file or be computed from $songs
$songURL = "$publicSite$publicSongs";
$songlistFile = "$songDir$songlistFile";


### Option variables and their defaults:

$verbose = 0;					# be verbose
$format = "";					# output format

$message = "";					# error message
$status = 0;					# result status code

$hex = 0;					# number lists in hex
$dec = 0;					# number in decimal also
$long = 0;					# include descriptions
$html = 0;					# output html
$multi = 0;					# multisession (CD_ROM_XA)
$sound_links = 0;				# show sound-file links
$ctitle = "";					# collection (album) title

### Variables set from song macros:
$title = "";
$subtitle = "";
$notice = "";
$license = "";
$dedication = "";
$description = "";
$category = "";
$key = "";
$timing = "";
$created = "";
$cvsid = "";
					## stuff for CD text
$performer = $default_performer;		# performer
$lyrics = "";					# lyricist
$music = "";					# composer
$arranger = "";					# arranger
					## derived:
$index_title = "";				# title without leading A/The
$filename  = "";				# filename.flk
$shortname = "";				# filename without .flk

$track = "";					# track data file from cmd line
$track_data = "";				# actual track data file


##########################################################################
### Main Program:
##########################################################################

$i = 0;
$morefiles = "";

foreach $f (@ARGV) {
    if ($f =~ /^-/) {
	if    ($f =~ /--?cd/)     { $format = "cd"; }
	elsif ($f =~ /--?java/)   { $format = "java"; }
	elsif ($f =~ /--?ogg/)    { $format = "ogg"; }
	elsif ($f =~ /--?mp3/)    { $format = "mp3"; }
	elsif ($f =~ /--?shell/)  { $format = "shell"; }
     	elsif ($f =~ /--verbose/) { ++$verbose; }
	elsif ($f =~ /-v/)        { ++$verbose; }
	elsif ($f =~ /--?hex/)	  { ++$hex; }
	elsif ($f =~ /--?dec/)	  { ++$dec; }
	elsif ($f =~ /-x/)        { ++$hex; }
	elsif ($f =~ /-l/)	  { ++$long; }
	elsif ($f =~ /--?long/)	  { ++$long; }
	elsif ($f =~ /--?multi/)  { ++$multi; }
	elsif ($f =~ /--?sound/)  { ++$sound_links; }
	else {
	    print $usage;
	    exit 1;
	}
    } elsif ($f =~ /\@(.+)/) {			# @tracklist-file
	$morefiles = `grep -v \# $1`;
	$morefiles =~ s/\n/ /gs;
    } elsif ($f =~ /format=(.+)/) { 
	$format = $1; 
	if ($format eq "list") { $format = "list.text"; }
	if ($format eq "text") { $format = "list.text"; }
	if ($format eq "tracklist") { $format = "list.text"; }
	if ($format eq "html") { $format = "list.html"; }
	if ($format =~ /html/) { $html = 1; }
    } elsif ($f =~ /title=(.+)/)  {		# collection title
	$ctitle = $1; 
    } elsif ($f =~ /track=(.+)/)  { 		# track (.wav file)
	$track = $1; 				#   for next song only
    } elsif ($f =~ /performer=(.+)/)  { 	# performer (sticky)
	$performer = $1; 
    } else {
	if ($i == 0) { printHeading(); }
	#if ($i > 0) { print "\n"; }
	getTrackInfo($f);
	printInfo($format);
	print "\n";
	++$i;
    }
}
if ($morefiles) {
    for $f (split(/ +/, trim($morefiles))) {
	if ($i == 0) { printHeading(); }
	#if ($i > 0) { print "\n"; }
	getTrackInfo($f);
	printInfo($format);
	print "\n";
	++$i;
    }
}

printFooting();

if ($verbose) {
    print STDERR "*** $i songs processed\n";
}

exit($status);


##########################################################################

sub songLinks {
    my $content = '';

    for my $f (@list) {
	my $ttl = $titleMap{$f};
	if (-f "$songDir/$f.html") {
	    $content .= "   <a href='$songURL$f.html'>$ttl</a>";
	} else {
	    $content .= $ttl;
	}
	$content .= "<br />\n";
    }
    $content;
}

sub opLink {
    my ($f, $op, $txt) = @_;
    my $list=join("+", @list);
    return ("<a href='$this?" .
	    ($ro? "ro=$ro;" : "") . 
	    ($pageTitle? "title=$pageTitle;" : "") . 
	    ($sort? "sort=$sort;" : "") . 
	    ($f? "name=$f;" : "") . 
	    ($op? "op=$op;" : "") .
	    ($cols? "cols=$cols;" : "") .
	    "list=$list'" .
	    ">$txt</a>");
}

# read-only URL for this setlist
sub roURL {
    my ($base) = @_;
    $$base = $this unless $base;
    my $list=join("+", @list);
    return ("$this?" .
	    "ro=$ro;" . 
	    ($pageTitle? "title=$pageTitle;" : "") . 
	    ($cols? "cols=$cols;" : "") .
	    "list=$list");
}


# entity encode (protect) a string
sub entityEncode {
    my ($s) = @_;
    $s =~ s/\&/&amp;/gs;
    $s =~ s/\>/&gt;/gs;
    $s =~ s/\</&lt;/gs;
    return $s;
}

sub trim {
    my ($s) = @_;
    $s =~ s/^[ \t\n]*//gs;
    $s =~ s/[ \t\n]*$//gs;
    return $s;
}

### clearTrackInfo()
#	Clear the global variables we stuff the track info into.
#
sub clearTrackInfo {
    $title = "";
    $short_title = "";
    $subtitle = "";
    $notice = "";
    $license = "";
    $dedication = "";
    $description = "";
    $category = "";
    $key = "";
    $timing = "";
    $created = "";
    $cvsid = "";

    $url = "";			    	# === compute; check for longdir

    						# don't clear performer
    $lyrics = "";				# lyricist
    $music = "";				# composer
    $arranger = "";				# arranger

    $track_data = "";				# .wav file
}

### getSongFileInfo($filename)
#	Get information from a song (.flk) file
#	The results are returned in global variables, which are assumed to
#	have been initialized already.
#
sub getSongFileInfo {
    my $filename = shift;
    my $shortname = $filename;

    if ($filename =~ /^([0-9]+\-+)?([^.]+)\.?/) { 
	$shortname = $2;
    }

    open(IN, "$songDir/${filename}.flk") || return 0;
    
    while (<IN>) {			
	if (/^[ \t]*$/) { }		# blank line
	elsif (/^[ \t]*\%.*$/) { }	# comment: ignore

    # Variable-setting macros:

	elsif (/\\begin\{song/)	{ begSong($_); }  # \begin{song}{title}

	elsif (/\\subtitle/)  	{ $subtitle	= getContent($_); }
	elsif (/\\key/)  	{ $key		= getContent($_); }
	elsif (/\\category/)	{ $category	= getContent($_); }
	elsif (/\\dedication/)	{ $dedication	= getContent($_); }
	elsif (/\\description/)	{ $description	= getContent($_); }
	elsif (/\\license/) 	{ $license	= getContent($_); }
	elsif (/\\timing/)  	{ $timing    = getContent($_); }
	elsif (/\\created/)  	{ $created   = getContent($_); }
	elsif (/\\notice/)  	{ $notice    = getContent($_); }
	elsif (/\\cvsid/)	{ $cvsid     = getContent($_); }
	elsif (/\\music/)	{ $music     = getContent($_); }
	elsif (/\\lyrics/)	{ $lyrics    = getContent($_); }
	elsif (/\\arranger/)	{ $arranger  = getContent($_); }
	elsif ($title) { 
	    # everything's at the top, so we have it all now.
	    last;
	}
    }
    
    close(IN);
    return 1;
}


### getTrackInfo($filename)
#	Get information for a track.
#	The results are returned in global variables, which is ugly
#	but works in this case.
#
sub getTrackInfo {
    $filename = shift;
    $shortname = $filename;

    # Extract the shortname from the filename:
    #   a leading numeric prefix separated by hypens is ignored.
    #   everything after "." is ignored.  This allows track numbers
    #   and qualifiers (foo.a, etc.)
    if ($filename =~ /^^([0-9]+\-+)?([^.]+)\.?/) { 
	$shortname = $2;
    }

    clearTrackInfo();

    getSongFileInfo($shortname);

    #print STDERR "shortname = $shortname; title = $title\n";
    $title = $shortname unless $title;

    # Set index_title (for sorting) from title
    $index_title = "" . $title;
    $index_title =~ s/^(An? |The )//;

    # If lyricist specified but composer isn't, composer is the default
    $music  = $default_songwriter if ! $music && $lyrics;

    # If lyricist isn't specified, it's the default
    $lyrics = $default_songwriter unless $lyrics;

    # look for a .wav file in ../Tracks/$shortname/
    
    $trackddir = "$trackDir/$shortname";
    $trackddir = "" unless -d $trackddir;
    if ($track) {
	# track data (wav file) specified on command line
	$track_data = $track;
	$track = "";
    } elsif ($filename =~ /.wav$/ && -f $filename) {
	$track_data = $filename;
    } elsif (-f "${filename}.wav") {
	$track_data = "${filename}.wav";
    } elsif ($trackddir) {
	# track data from ../tracks/$shortname
	#   if there's more than one, it takes the last (most recent) one
	$track_data = `ls -tr $trackddir | grep .wav | tail -1`;
	$track_data = $trackddir . "/" . trim($track_data);
    } else {
	$track_data = "";
    }
}

sub printInfo {
    $track_number = ($track_number)? $track_number + 1 : 1;
    if ($format eq "cd") {
	# One would think that there should be a subchannel, but that fails.
	# === current cdrdao is probably screwed up somehow ===

	# every track needs a composer now, so use the songwriter unless 
	# we already have one.
	$music = $lyrics unless $music; 
	
	print "TRACK AUDIO\n";
	print "COPY\n";
	print "CD_TEXT {\n";
        print "  LANGUAGE 0 {\n";
	print "    TITLE \"$title\"\n";
        print "    PERFORMER \"$performer\"\n";
        print "    SONGWRITER \"$lyrics\"\n";
        print "    COMPOSER \"$music\"\n" if $music;
        print "    ARRANGER \"$arranger\"\n" if $arranger;
        print "  }\n";
	print "}\n";
	# PREGAP used to work; it now causes an error:
	#     START 00:02:00 behind or at track end.
	# The one in sarge still works, so copy that to /usr/local/bin.
	print "PREGAP 0:2:0\n";
	print "SILENCE 0:0:1\n";		# make new cdrdao happy
	#print "SILENCE 0:2:0\n";
	#print "START 0:2:0\n";
	print "FILE \"$track_data\" 0\n";
	if (! $track_data) {
	    $status = -1;
	    print STDERR "SongInfo:  No track data for $shortname ($title)\n";
	}
    } elsif ($format eq "files") {
	# Just the track file names
	print "$track_data";
    } elsif ($format eq "songs") {
	# Just the corresponding shortnames
	print "$shortname";
    } elsif ($format eq "list.text") {
	# the timing really needs to come off the track_data if present ===
	my $d = ($hex && $dec)? sprintf("(%02d) ", $track_number) : "";
	if ($hex) {
	    print sprintf("0x%02x", $track_number) . " $d$title ($timing)";
	} else {
	    print sprintf("  %2d:", $track_number) . " $title ($timing)";
	}
	if ($long) {
	    $description =~ s/\n[ \t]*/\n      /gs;
	    print "\n      $description";
	}
    } elsif ($format eq "list.html") {
	my $d = ($hex && $dec)? sprintf("(%02d) ", $track_number) : "";
	print ("  <tr> \n");
	print ("    <td align='right'> " .
	       ($hex? sprintf("0x%02x", $track_number) : $track_number) .
	       " </td>\n");
	print ("    <td align='right'> " .
	       sprintf("(%02d)", $track_number) .
	       " </td>\n") if $hex && $dec;
	print ("    <td> ");
	if (-f "$f.ogg" && $sound_links) {
	    # put the sound file first -- this is a concert after all
	    print " <a href='$f.ogg'>[ogg]</a>";
	}
	print ("    </td>\n");
	print ("    <td> ");
	if (-f "$f.mp3" && $sound_links) {
	    # put the sound file first -- this is a concert after all
	    print " <a href='$f.mp3'>[mp3]</a>";
	}
	print ("    </td>\n");
	print ("    <td> ");
	if (-f "$songDir/$shortname.html") {
	    print "<a href='$songURL$shortname.html'>$title</a>";
	} elsif ($shortname =~ /(.+)_(.+)/) {
	    $s1 = $1; $s2 = $2;
	    if ($title =~ /(.+) *\/ *(.+)/) {
		$t1 = $1; $t2 = $2; $ts = " / ";
	    } else {
		$t1 = $s1; $t2 = $s2; $ts = " ";
	    }
	    if (-f "$songDir/$s1.html") {
		print "<a href='$songURL$s1.html'>$t1</a>$ts";
	    } else {
		print "$t1$ts";
	    }
	    if (-f "$songDir/$s2.html") {
		print "<a href='$songURL$s2.html'>$t2</a>";
	    } else {
		print $t2;
	    }
	    
	} else {
	    print "$title";
	}
	print ("    </td>\n");
	print ("  </tr>");
	if ($long && $description) {
	    print ("  <tr> \n");
	    print ("    <td> </td>\n");
	    print ("    <td> </td>\n");
	    print ("    <td> </td>\n");
	    print ("    <td> </td>\n");
	    print ("    <td> $description\n");
	    print ("    </td>\n");
	    print ("  </tr>"); 
	}
    } elsif ($format eq "ol.html") {
	print ("  <li> ");
	if (-f "$f.ogg") {
	    # put the sound file first -- this is a concert after all
	    print " <a href='$f.ogg'>[ogg]</a>";
	}
	if (-f "$songDir/$shortname.html") {
	    print "<a href='$songURL$shortname.html'>$title</a>";
	} else {
	    print "$title";
	}
	print " </li>";
    } elsif ($format eq "java") {
	# Java uses hierarchical property names of the form a.b
	# so we can use $shortname.property 
    } elsif ($format eq "ogg") {
	# Output an oggenc argument list.
	print "-a '$performer' ";
	print "-t \"$title\" " if $title;
	print "-c 'songwriter=$lyrics' ";
	print "-c 'composer=$music' "	 if $music;
	print "-c 'arranger=$arranger' " if $arranger;
	print "-l '$ctitle' " 		 if $ctitle;
	# === needs license and url
	print "$track_data\n";
    } elsif ($format eq "mp3") {
	# Output a lame argument list.
	print "--ta '$performer' ";
	print "--tt \"$title\" " if $title;
	#print "-c 'songwriter=$lyrics' ";
	#print "-c 'composer=$music' "	 if $music;
	#print "-c 'arranger=$arranger' " if $arranger;
	print "--tl '$ctitle' " 		 if $ctitle;
	# === needs license and url
	print "$track_data\n";
    } elsif ($format eq "shell") {
	# Shell is name='value' -- need single quotes to prevent expansion
	print "shortname='$shortname'\n";
	print "filename='$filename'\n";
	print "title='$title'\n";
	print "index_title='$index_title'\n";
	print "subtitle='$subtitle'\n" if $subtitle;
	# can't (easily) have multiline items in shell format
	#print "dedication='$dedication'\n" if $dedication;
	#print "description='$description'\n" if $description;
	# === needs license and url
	print "lyrics='$lyrics'\n";
	print "music='$music'\n" if $music;
	print "arranger='$arranger'\n" if $arranger;
	print "timing='$timing'\n" if $timing;
	print "category='$category'\n" if $category;
	print "key='$key'\n" if $key;
	print "created='$created'\n" if $created;
	print "cvsid='$cvsid'\n" if $cvsid;
    } else {
	# Sort of a generic java/make format suitable for a only single song
	print "shortname=$shortname\n";
	print "filename=$filename\n";
	print "title=$title\n";
	print "index_title=$index_title\n";
	print "subtitle=$subtitle\n" if $subtitle;
	print "lyrics=$lyrics\n";
	print "music=$music\n" if $music;
	print "arranger=$arranger\n" if $arranger;
	print "timing=$timing\n" if $timing;
	print "category=$category\n" if $category;
	print "key=$key\n" if $key;
	print "created=$created\n" if $created;
	print "cvsid=$cvsid\n" if $cvsid;
        #$notice $license $dedication 
    }
}

sub printHeading {
    if ($format eq "cd" && $ctitle) {
	# multisession disks have to be type CD_ROM_XA
	print ($multi? "CD_ROM_XA" : "CD_DA");
	print "
CD_TEXT {
  LANGUAGE_MAP {
    0 : EN
  }

  LANGUAGE 0 {
    TITLE \"$ctitle\"
    PERFORMER \"$default_performer\"
  }
}\n\n";
    } elsif ($format eq "tracklist" && $ctitle) {
	print "Track list for $ctitle\n";
    } elsif ($format eq "list.html") {
	print "<table class='tracklist'>\n";
    } elsif ($format eq "ol.html") {
	print "<ol>\n";
    }
}

sub printFooting {
    if ($format eq "list.html") {
	print "</table>\n";
    } elsif ($format eq "ol.html") {
	print "</ol>\n";
    }
}



########################################################################
###
### Macro handlers:
###
###	Each of the following routines handles a LaTeX macro.
###

### Separate verses.
sub sepVerse {
    if ($vlines) { endVerse(); }
}

### Handle a blank line.
sub blankLine {
    if ($vlines) { endVerse(); }
    if ($plain) {
	print "\n";
	$plines = 0;
    }
}

### Begin a song:
###	Stash the title.
sub begSong {
    my ($line) = @_;		# input line
    $line =~ s/^.*song\}//;
    $title = getContent($line);	
}


########################################################################
###
### Block conversion:
###
###	Each of these routines converts the start or end of a
###	delimited block of lines to output format.
###

sub doHeader {
    if ($html)	{ htmlHeader(); }
    else	{ textHeader(); }
    $header ++;
}

sub center {
    # === need to handle multiple lines ===
    my ($text) = @_;
    $text =~ s/^[ \t]*//;
    $text =~ s/[ \t]*\n$//;
    $text =~ s/\\copyright/Copyright/;

    my $w = $WIDTH - length($text);
    for ( ; $w > 0; $w -= 2) { $text = " " . $text; }
    print "$text\n";
}

sub hcenter {
    my ($h, $text) = @_;
    $text =~ s/^[ \t]*//;
    $text =~ s/\\copyright/\&copy;/;
    $text =~ s/\n/\<br\>/g;
    $text = "<h$h align=center>$text</h$h>";
    print "$text\n";
}

sub textHeader {
    center "$title\n";
    if ($subtitle) 	{ center "$subtitle\n"; }
    if ($notice) 	{ center "$notice\n"; }
    if ($license)	{ center "$license\n"; }
    if ($dedication) 	{ center "$dedication\n"; }
    print "\n";
}
sub htmlHeader {
    hcenter 1, $title;
    if ($subtitle) 	{ hcenter 2, $subtitle; }
    if ($notice) 	{ hcenter 3, $notice; }
    if ($license)	{ hcenter 3, $license; }
    if ($dedication) 	{ hcenter 3, $dedication; }
    print "\n";
}

sub footer {

}

########################################################################
###
### Line conversion:
###
###	Each of these routines converts a single line of mixed chords
###	and text. 
###

### Process the current line:
###	Does any necessary dispatching. 
sub doLine {
    # Put out the header, if this is the very first line. 
    if (! $header) { doHeader(); }
    if ($plain) {
	if ($plines == 0) { 
	    if ($html) { print "<p>\n"; }
	    else { print "\n"; }
	} 
	$_ = deTeX($_);
	#if ($html) { s/\~/&nbsp;/g; } else { s/\~/ /g; }
	s/\\newline/$NL/g;
	s/\\\///g;
	indentLine($_, $indent);
	$plines ++;
    } else {
	if ($vlines == 0) { begVerse(); }
	if ($tables) { print tableLine($_); }
	else 	     { print chordLine($_); }
	$vlines ++;
    }
}

### Put out a plain line, possibly indented.
sub indentLine {
    my ($line, $indent) = @_;

    $line =~ s/^[ \t]*//;
    while ($indent--) { $line = " ".$line; }
    print $line;
}

### Convert an ordinary line to chords + text
# === does not insert indent yet.
sub chordLine {
    my ($line) = @_;		# input line
    my $cline = "";		# chord line
    my $dline = "";		# dest. (text) line
    my ($scol, $ccol, $dcol, $inchord, $inmacro) = ($indent, 0, 0, 0, 0);
    my $c = '';			# current character
    my $p = 0;			# current position

    $line = deTeX($line);

    $line =~ s/^[ \t]*//;
    $line =~ s/\\sus/sus/g;
    $line =~ s/\\min/m/g;

    for ($p = 0; $p < length($line); $p++) {
	$c = substr($line, $p, 1); 
	if    ($c eq "\n" || $c eq "\r") { break; }
	if    ($c eq '[') { $inchord ++; }
	elsif ($c eq ']') { $inchord --; }
	elsif ($c eq ' ') { if (!$inchord) { $scol ++; } }
	elsif ($c eq "\t") {
	    if (!$inchord) { do {$scol ++; } while ($scol % 8); } }
	else {
	    if ($inchord) {
		while ($ccol < $scol) { $cline .= ' '; $ccol ++ }
		$cline .= $c;
		$ccol ++;
	    } else {
		while ($dcol < $scol) { $dline .= ' '; $dcol ++ }
		$dline .= $c;
		$dcol ++;
		$scol++;
	    }
	}
    }

    # The result has a newline appended to it.
    return (($cline eq "")? $dline : $cline . "\n" . $dline);
}

### Convert a line to a table
###   When using tables, each line becomes a separate table.
###   This, in turn, becomes a row in a table containing the verse.
sub tableLine {

}

### Convert a line to XML
sub xmlLine {

}

### Remove LaTeX constructs.
###	This would be easier with a table.
sub deTeX {
    my ($txt) = @_;		# input line

    while ($txt =~ /\%/) {	# TeX comments eat the line break, too.
	$txt =~ s/\%.*$//;
	$txt .= <STDIN>;
     }
    while ($txt =~ /\{\\em[ \t\n]/
	   || $txt =~ /\{\\tt[ \t\n]/
	   || $txt =~ /\{\\bf[ \t\n]/) {
	# This will fail if there's a \bf and \em in one line in that order
	if ($txt =~ /\{\\em[ \t\n]/) {
	    $txt =~ s/\{\\em[ \t\n]/$EM/; 
	    while (! $txt =~ /\}/) { $txt .= <STDIN>; }
	    $txt =~ s/\}/$_EM/;
	}
	if ($txt =~ /\{\\tt[ \t\n]/) {
	    $txt =~ s/\{\\tt[ \t\n]/$TT/; 
	    while (! $txt =~ /\}/) { $txt .= <STDIN>; }
	    $txt =~ s/\}/$_TT/;
	}
	if ($txt =~ /\{\\bf[ \t\n]/) { 
	    $txt =~ s/\{\\bf[ \t\n]/$BF/; 
	    while (! $txt =~ /\}/) { $txt .= <STDIN>; }
	    $txt =~ s/\}/$_BF/;
	}
    }
    if ($html) { $txt =~ s/\~/&nbsp;/g; } else { $txt =~ s/\~/ /g; }
    while ($txt =~ /\\link\{[^}]+\}\{[^}]+\}/s) {
	if ($html) {
	    $txt =~ s/\\link\{([^}]+)\}\{([^}]+)\}/<a href="$1">$2<\/a>/s;
	} else {
	    $txt =~ s/\\link\{([^}]+)\}\{([^}]+)\}/$2/s;
	}
    }   
    $txt =~ s/\\&/$AMP/g;
    $txt =~ s/\\;/$SP/g;
    $txt =~ s/\\ /$SP/g;
    $txt =~ s/\\ldots/.../g;
    $txt =~ s/\\\\/$NL/g;

    $txt =~ s/\\min/m/g;
    $txt =~ s/\\capo/ capo/g;

    return $txt
}


### getContent(line): get what's between macro braces.
#
sub getContent {
    my ($line) = @_;		# input line
    # Throw away everything up to the "{"
    $line =~ s/^[^{]*\{//;
    $line = deTeX($line);
    # Suck in more lines if we haven't seen the closing brace
    # NOTE that we have to use the same file handle as getSongInfo!!
    while ($line !~ /\}/) { $line .= <IN>; $line = deTeX($line); }
    # Throw away everything after the "}"
    $line =~ s/\}[^}]*$//;
    $line =~ s/\n$//;
    return $line;
}
