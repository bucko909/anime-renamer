#!/usr/bin/perl

use warnings;
use strict;

use CGI;
use Net::BitTorrent::File;

our @exts = qw/avi mpg mp4 ogm mkv wmv ass flac/;
our @mediadirs = qw#
	#;
#our @notdirs = qw#/media/peer2peer/btcurrent /media/peer2peer/btwaiting /media/peer2peer/btpaused#;
#our $azdir = "/media/peer3peer/azureus_torrents";
our $union = "/union/all";
our $LOG = "/home/bucko/public_html/btlog";

our $root = "/media/sdg1";

our @search = qw/lan/;





our @series_episode = (
	[qr/(?:-\s+)?S(\d+)\b/i => [[Series => '$1'], undef]],
	[qr/(?:-\s+)?\bSeries\s*(\d+)\b/i => [[Series => '$1'], undef]],
	[qr/(?:-\s+)?\b2nd\s+Season\b/i => [[Series => '2'], undef]],
	[qr/(?:-\s+)?\bMovie\s*(\d+)\b/i => [[Movie => '$1'], undef]],
	[qr/(?:-\s+)?\bTV PV\s*(\d+)/i => [undef, ['PV' => '$1']]],
	[qr/(?:-\s+)?\bOVA\s+(\d+)\s+-\s+(\d+)/i => [[OVA => '$1'], '$02']],
	[qr/(?:-\s+)?\bOVA\s*(?:-\s+)?(\d+)/i => [OVA => '$1']],
	[qr/(?:-\s+)?\b(?:Creditless\s+(ED|OP))\s*(\d+[ab]?)/i => [undef, ['NC$1' => '$02']]],
	[qr/(?:-\s+)?\b(?:Creditless\s+(ED|OP))\b/i => [undef, 'NC$1']],
	[qr/(?:-\s+)?(?:Ep\s*(\d+))\s+\b(?:Creditless\s+Ending)\b/i => [undef, 'NCED - Ep$01']],
	[qr/(?:-\s+)?(?:Ep\s*(\d+))\s+\b(?:Creditless\s+Opening)\b/i => [undef, 'NCOP - Ep$01']],
	[qr/(?:-\s+)?\b(?:Intro(?:duction)?)\s*(\d+[ab]?)/i => [undef, [Introduction => '$1']]],
	[qr/(?:-\s+)?\b(?:Intro(?:duction)?)\b/i => [undef, 'Introduction']],
	[qr/(?:-\s+)?\b(?:Commentary)\s*(\d+[ab]?)/i => [undef, [Commentary => '$1']]],
	[qr/(?:-\s+)?\b(?:Commentary)\b/i => [undef, 'Commentary']],
	[qr/(?:-\s+)?\b(?:Opening)\s*(\d+[ab]?)/i => [undef, [OP => '$1']]],
	[qr/(?:-\s+)?\b(?:Opening)\s*(?:-\s+)?(.+?)\s*$/i => [undef, [OP => '$1']]],
	[qr/(?:-\s+)?\b(?:Opening)\b/i => [undef, 'OP']],
	[qr/(?:-\s+)?\b(?:Ending)\s*(\d+[ab]?)/i => [undef, [ED => '$1']]],
	[qr/(?:-\s+)?\b(?:Ending)\s*(?:-\s+)?(.+?)\s*$/i => [undef, [ED => '$1']]],
	[qr/(?:-\s+)?\b(?:Ending)\b/i => [undef, 'ED']],
	[qr/(?:-\s+)?\b((?:NC)?(?:ED|OP)|PV)\s*(\d+[ab]?)/i => [undef, ['$1' => '$02']]],
	[qr/(?:-\s+)?\b((?:NC)?(?:ED|OP)|PV)\b/i => [undef, '$1']],
	[qr/(?:-\s+)?\b(?:(?-i:SP)|Special)\s*(?:-\s+)?(\d+)/i => [undef, [Special => '$01']]],
	[qr/(?:-\s+)?\b(?:(?-i:SP)|Special)\s*(?:-\s+)?(.+?)\s*$/i => [undef, ['Special -' => '$01']]],
	[qr/(?:-\s+)?\b(?:(?-i:SP)|Special)\b\s*/i => [undef, ['Special']]],
	[qr/-\s+(?:[Ee]ps\s*)(\d+-\d+)/ => [undef, '$01']],
	[qr/-\s+(?:[Ee](?:p\s*)?)(\d+)\s+-\s+([^\[\]\(\)]+)/ => [undef, '$01 - $2']],
	[qr/\s+(?:[Ee](?:p\s*)?)(\d+)\s+-\s+([^\[\]\(\)]+)/ => [undef, '$01 - $2']],
	[qr/\s+(\d+)\s+-\s+([^\[\]\(\)]+)/ => [undef, '$01 - $2']],
	[qr/-\s+(?:[Ee](?:p\s*)?)(\d+)\s+'([^']+)'/ => [undef, '$01 - $2']],
	[qr/\s+(?:[Ee](?:p\s*)?)(\d+)\s+'([^']+)'/ => [undef, '$01 - $2']],
	[qr/\s+(?:[Ee](?:p\s*)?)(\d+)\s+(.+)/ => [undef, '$01 - $2']],
	[qr/-\s+(?:[Ee](?:p\s*)?)(\d+)(?:v\d)?/ => [undef, '$01']],
	[qr/\s+(?:[Ee](?:p?\s*)?)(\d+)(?:v\d)?/ => [undef, '$01']],
	[qr/-\s+(\d+)(?:v\d)?/ => [undef, '$01']],
	[qr/\s+(\d+)(?:v\d)?/ => [undef, '$01']],
);

our @video_modes = (
	[qr/(h|x)264/i => 'h264'],
	[qr/xvid/i => 'XviD'],
	[qr/x1080|1080p/ => '1080p'],
	[qr/x720|720p/ => '720p'],
	[qr/x480|480p/ => '480p'],
	[qr/x560|560p/ => '560p'],
	[qr/Blu-Ray|BD/i => 'BD'],
);

our @junk = (
	qr/^[0-9A-F]{8}$/i,
	qr/^DVD$/,
);

my $q = new CGI;
print $q->header;
print $q->start_html("Renamer!");

my $mode = $q->param('mode') || 'list';
if ($mode eq 'rename') {
	$|=1;
	print $q->h1("Renaming")."\n";
	my $file = $q->param('file');
	my $dir = $q->param('dir');
	my $to = $q->param('to');
	print "<p>$file to $dir/$to</p>\n";
	my $troot = $dir;
	$troot =~ s#/(?:public|private)/[^/]+$##;
	if (!grep {$_ eq $troot} @mediadirs) {
		print $q->p("Invalid root dir: $dir ($troot)");
		print $q->end_html;
		exit;
	}
	if ($file =~ /(?:^|\/)\.\.\//) {
		print $q->p("Invalid file: $file");
		print $q->end_html;
		exit;
	}
	my $qf = "$root/$file";
	$qf =~ s/"/\\"/g;
	my $qt = "$dir/$to";
	$qt =~ s/"/\\"/g;
	if (my $err = `mv -n "$qf" "$qt" 2>&1`){
		chomp $err;
		print "<p>Failed to rename: $err</p>\n";
		print $q->end_html;
		exit;
	}
	my $fdir = $file;
	$fdir =~ s#/.*$##;
	my $torr = "$root/btdone/$fdir.torrent";
	if (-e $torr) {
		unlink($torr);
		print "<p>Also removed $torr.</p>\n";
	}
	&log("Rename $file to $dir/$to");
	print "Done.";
	print $q->end_html;
	exit;
} elsif ($mode eq 'reunion') {
	print $q->h1("Regenerating");
	system("/home/media/makeunion.pl 2>&1");
	print "Done.";
	print $q->end_html;
	exit;
}

my @dirs = map {[$_, ""]} @search;
my @files;
while(@dirs) {
	my ($dir, $subdir) = @{shift @dirs};
	opendir DIR, "$root/$dir" or die "$root/$dir: $!";
	while($_ = readdir DIR) {
		if ( -d "$root/$dir/$_" && !/^\.*$/)
		{
			push @dirs, ["$dir/$_", "$subdir/$_"];
			next;
		}
		foreach my $ext (@exts) {
			if (/\.$ext$/i) {
				my @s = stat("$root/$dir/$_");
				next if $s[7] < 1000000;

				push @files, ["$dir/$_", "$subdir/$_"];
				# substr($dir.'/'.$_, 1); <-- hack for when we search "$root/." as "$root"
			}
		}
	}
	closedir DIR;
}
@files = sort { $a->[0] cmp $b->[0] } @files;


#my @notfiles;
#foreach my $dir (@notdirs) {
#	opendir DIR, $dir;	
#	while($_ = readdir DIR) {
#		if ( /\.torrent$/)
#		{
#			push @notfiles, &file_list("$dir/$_");
#		}
#	}
#}
#open THING, "wget -q -O - http://newton.hoe:57097/index.tmpl | grep '<span class=\"a\" id=\"tor[0-9]*\" title=\"' | cut -d'\"' -f6 | sed 's/\$/.torrent/' |";
#while($_ = <THING>) {
#	if ( /\.torrent$/)
#	{
#		push @notfiles, &file_list("$azdir/$_");
#	}
#}
#close THING;
#@notfiles = sort @notfiles;

#@files = grep { my $tmp = $_; !scalar grep { $tmp eq $_ } @notfiles } @files;

print $q->h1("Renamer");

print qq#<p><a href="?mode=reunion">Regenerate Union</a></p>#;

print $q->start_table;

foreach my $bits (@files) {
	my ($old, $filebit) = @$bits;
	my ($sname, $fname) = decode_name($filebit);

	my ($target, $rname) = &find_dir($sname);
	if ($rname) {
		$sname = $rname;
	}
	if ($fname =~ /^\s*[^\s*\[\(]+\s+/) {
		$fname = "$sname - $fname";
	} elsif ($fname =~ /^\./) {
		$fname = "$sname$fname";
	} else {
		$fname = "$sname $fname";
	}

	print "<tr>";
	print "<td>$old</td>";
	print "<td><a href=\"?mode=rename&amp;file=".&url_encode($old)."&amp;to=".&url_encode("$sname/$fname")."&amp;dir=".&url_encode("$target")."\">$target</a></td>" if $target;
	print "<td>Not found!</td>" unless $target;
	print "<td>$sname/$fname</td>";
	print "</tr>";
}

print $q->end_table;
print $q->end_html;

sub decode_name {
	my ($fname) = @_;
	$fname =~ s|^.*/||g;
	$fname =~ s/\.([^\.]+)$//g;
	my $ext = $1;
	
	$fname =~ s/_/ /g;
	if ($fname !~ / /) {
		if ($fname =~ /\./) {
			$fname =~ s/\./ /g;
		}
	}
	my @gubbins;
	$fname =~ s/\[([^\]]*)\]|\(([^\)]*)\)/push @gubbins, ($1||$2);""/eg;
	$fname =~ s/^ *| *$//g;

	my $group;
	my @vdetails;
	if ($fname =~ s/[_ ]-[_ ]THORA//i) {
		# Bastards
		$group = 'THORA';
	}
	for my $gubb (@gubbins) {
		next if grep { $gubb =~ /$_/ } @junk;
		my $vmode_got;
		for my $vmode (@video_modes) {
			if ($gubb =~ /$vmode->[0]/) {
				push @vdetails, $vmode->[1];
				$vmode_got = 1;
			}
		}
		next if $vmode_got;
		$group = $gubb;
	}

	my ($sname, $ename);
	for (@series_episode) {
		my ($patt, $res) = @$_;
		next if defined $sname && defined $res->[0];
		next if defined $ename && defined $res->[1];
		my $ofname = $fname;
		if ($fname =~ s/$patt//) {
			no strict qw/refs/;
			my @bits = map { ${$_} } 1..$#+;
			$sname = decode($res->[0], @bits) if defined $res->[0];
			$ename = decode($res->[1], @bits) if defined $res->[1];
		}
	}

	$fname =~ s/\s+/ /g;
	$fname =~ s/^ *| *$//g;
	if (defined $sname) {
		$sname = "$fname - $sname";
	} else {
		$sname = $fname;
	}

	if (defined $ename) {
		$fname = $ename;
	} else {
		$fname = "";
	}

	if ($group) {
		$fname = "$fname [$group]";
	}

	if (@vdetails) {
		my $gubbins = join ' ', map { "($_)" } @vdetails;
		$fname = "$fname $gubbins";
	}

	return ($sname, "$fname.$ext");
}

sub decode {
	my ($patt, @bits) = @_;
	return undef unless defined $patt;
	if (ref $patt) {
		return join ' ', map { decode($_, @bits) } @$patt;
	}
	$patt =~ s/\$(\d+)/maybe_num($bits[$1-1], $1)/eg;
	return $patt;
}

sub maybe_num {
	my ($data, $varnum) = @_;
	if (($data =~ /^[0-9]+$/) && ($varnum =~ /^0\d/)) {
		return sprintf("%02i", $data);
	}
	return $data;
}

sub find_dir {
	my $dir = $_[0];
	return ('/', $dir);
	my $tdir = lc $dir;
	$tdir =~ s/[ .!-]//g;

	my ($target1, $target2);
	foreach(qw/Anime TV Video/) {
		opendir DIR, "$union/$_";
		while (my $nam = readdir DIR) {
			my $tnam = lc $nam;
			$tnam =~ s/[ .!-]//g;
			if ($tnam eq $tdir) {
				$target1 = $_;
				$target2 = $nam;
				last;
			}
		}
		closedir DIR;
		last if $target1;
	}

	return unless $target1;

	my $ln;
	if ($ln = readlink "$union/$target1") {
		return ("$ln", $target2);
	} elsif ($ln = readlink "$union/$target1/$target2") {
		$ln =~ s#/[^/]*$##;
		return ($ln, $target2);
	} elsif ($target1) {
		# New anime dirs look like this.
		opendir DIR, "$union/$target1/$target2";
		my $last = -1;
		my $dir;
		while (my $nam = readdir DIR) {
			if ($nam =~ /- (\d+)/ && $1 > $last) {
				$last = $1;
				my $file = readlink "$union/$target1/$target2/$nam";
				if ($file =~ m#^(/mnt/media[^/]+/[^/]+)#) {
					$dir = $1;
				}
			}
		}
		closedir DIR;
		if ($last == -1 || !$dir) {
			# No anime files; just pick anything?
			opendir DIR, "$union/$target1/$target2";
			while (my $nam = readdir DIR) {
				next if $nam =~ /^\.*$/;
				my $file = readlink "$union/$target1/$target2/$nam";
				if (!$file) {
					print "<p>Not a softlink: $union/$target1/$target2/$nam</p>";
					next;
				}
				if ($file =~ m#^(/disks/media[^/]+/(?:public|private)/[^/]+)#) {
					$dir = $1;
					last;
				}
			}
			closedir DIR;
			if (!$dir) {
				print $q->p("Warning Will Robinson; $union/$target1/$target2 has no softlinks!");
			}
		}
		return ($dir, $target2);
	}
}

sub file_list {
	my ($filename) = @_;

	my $torrent = eval { Net::BitTorrent::File->new($filename) };

	unless($torrent) {
		print $q->p("Couldn't load $filename: Bad file!");
		return ();
	}

	return $torrent->files ? (map { join ('/', $torrent->name(), @{$_->{path}}) } @{$torrent->files}) : ($torrent->name);
}

sub url_encode {
	my $temp = $_[0];
	#$temp =~ s/([^A-Za-z0-9])/"%".unpack('H2',$1)/eg;
	return $temp;
}

sub log {
	open LOG, '>>'.$LOG or print "Couldn't open log: $!\n";
	print LOG localtime()." / ".$ENV{REMOTE_ADDR}." (".&get_host()."): ".$_[0]."\n";
	close LOG;
}

sub get_host {
	$_ = `host $ENV{REMOTE_ADDR}`;
	/domain name pointer (\S+\.\w+)\./ && return $1;
	return "?";
}
