#!/usr/bin/perl -w
use strict;
use CGI qw/:standard/;

# init globals
my ($root,@dirs, %pdf, %doc, %dual, $pdf_count, $doc_count);
my @types = ('in_pdf','in_doc');
my $hashes = { $types[0]=>\%pdf, $types[1]=>\%doc };
my $pretty = { $types[0]=>'pdf', $types[1]=>'doc' };
# reusable regex
my $filename = ".+";
my $extention = "[dD][oO][cC]|[pP][dD][fF]";
my $pdf_re = qr/pdf$/i;

&start_the_html;
&display_form;
&display_results if param;
&end_the_html;

sub display_results{
  print hr;

	my %selected_types = map {$_ => undef} param('target_filetypes');
	my $both = exists($selected_types{'in_both'});
	my $count = param('count_requests');
	$root = param("datasheets_path");
	my $log = param("log_path");
	
	&get_files($root);
	map{ &emit($$pretty{$_},$$hashes{$_}) if (exists($selected_types{$_})) } @types;
	
	&extract_dual if ($count or $both);
	&emit('dual format',\%dual) if $both;

	if ($count){
		&count_accesses($log);
		print h2("Number of pdf requests for dual format datasheets = $pdf_count");
		print h2("Number of doc requests for dual format datasheets = $doc_count");
	}
}

sub emit($$){
	my ($type,$hash) = @_;
	print h2("List of $type datasheets");
	print "$dirs[$$hash{$_}]$_<br>" foreach keys %$hash;
}

# given a path, puts directories in @dirs and datasheet names in %pdf and %doc
sub get_files($){
	my $path = shift;
	&match_file($path) if (-f $path); # regular file or symlink

	return unless (-d $path and $path !~ /\/\.{1,2}$/); # valid directory
	push @dirs, substr("$path/", length($root)+1); # store path in dirs
	&get_files("$path/$_") foreach &read_dir($path); # open and recurse
}

# finds which datasheets exist in both formats and puts them into %dual
sub extract_dual{	
	# find smallest hash
	my($small, $big) = keys(%pdf) < keys(%doc) ? (\%pdf, \%doc) : (\%doc, \%pdf);
	# iterate over it and query the big hash
	map{ $dual{$_} = delete $$big{$_} if $$big{$_} } keys %$small;
	# undefine broken hashes
	undef %pdf; 
	undef %doc;
}
# given the log path, finds total pdf_count and doc_count of GET requests for dual-formatted datasheets
sub count_accesses($){
	open LOG, shift or print h3("failed to open log: $! <br>") and die;
	map {&match_get_request} <LOG>; # load only 1 line to memory
	close LOG;
}

# given a path, stores the filename and make it point to its containing directory in @dirs
sub match_file($){
	/($filename)\.($extention)$/o; # note: $_ doesn't include full path
	return unless ($2); # unsupported extention
	my($filename,$extention) = ($1,$2); 

	my $matched = ($extention =~ $pdf_re) ? \%pdf : \%doc; # select hash
	$$matched{$filename} = @dirs-1; # make point to last @dirs entry
}


# given a line from the log, increaments the correct count (iff the file requested exists in both formats)
sub match_get_request($){
	return unless (/ "GET .*\/($filename)\.($extention) /o);	
	return unless exists $dual{$1};

	($2 =~ $pdf_re) ? $pdf_count++ : $doc_count++
}

# given the path of a directory
sub read_dir($){
	opendir DIR, shift or print h3("failed to open dir: $! <br>") and die;
	my @files = readdir DIR;
	closedir DIR;
	return @files;
}

sub display_form{
	print start_form(-method=>'POST', -action=>'cw.pl');
	print i('Path for the datasheet hierarchy root?');
	print br;
	print textfield(-name=>'datasheets_path',
			-override=>1,
			-size=>20,
			-maxlength=>500);
	print br;
	print br;
	print i('Apach Log file path name?');
	print br;
	print textfield(-name=>'log_path',
			-override=>1,
			-size=>20,
			-maxlength=>500);
	print br;
	print br;
	print i('List datasheets which occur');
	print br;
	print checkbox_group(-name=>'target_filetypes',
			     -values=>['in_pdf','in_doc','in_both'],
			     -default=>['in_both'],
			     -linebreak=>'true');
	print br;
	print i('Apache log count of pdf requests and doc requests for datasheets in both formats');
	print br;
	print radio_group(-name=>'count_requests',
			  -values=>[1,0],
			  -default=>1,
			  -linebreak=>'true',
			  -labels=>{1=>'yes',0=>'no'});
	print br;
	print reset;
	print submit('Submit');
	print end_form;
}

sub start_the_html{
	print header;
	print start_html(-title=>'Knurled Widgets Website Tools');
	print h1('Knurled Widgets Website Tools');
}

sub end_the_html{
	print end_html;
}
