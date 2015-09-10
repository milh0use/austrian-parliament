package scraper;
use strict;
use warnings;
use LWP::UserAgent;

sub get_html {
	my ($country, $base_url, $use_cache) = @_;
	my $page_html;
	if ($use_cache && -e "cache/$country.dat") {
		open my $ifh, "<", "cache/$country.dat";
		my $record_separator = $/;
		$/ = undef;
		$page_html = <$ifh>; 
		$/ = $record_separator;
		close $ifh;
	}
	else {
		my $ua = LWP::UserAgent->new();
		my $response = $ua->get($base_url);
		if ($response->is_success()) {
			$page_html	= $response->decoded_content;
			if ($use_cache) {
				open my $ofh, ">", "cache/$country.dat";
				print $ofh $page_html;
				close $ofh;
			}
		}
	}
	return $page_html;
}

sub get_list {
	my ($list_regex,$page_html) = @_;
	$page_html =~ m|$list_regex|s;
	return $1;
}

1;
