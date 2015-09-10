use strict;
use warnings;
use LWP::UserAgent;
use lib "../shared";
use scraper;

# URL Parameters:
# GP - Session (eg I, II)
# M - Male, if set to M
# W - Female, if set to W

my @sessions = qw/ I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX XXI XXII XXIII XXIV XXV /;
my %params_for_gender = (
	'male'		=> 'M=M&W=',
	'female'	=> 'M=&W=W',
);
my $chamber_data = {
	'National Council'	=> {
		'code'			=> 'NationalCouncil',
		'base_url'		=> 'http://www.parlament.gv.at/WWER/NR/ABG/index.shtml?xdocumentUri=%2FWWER%2FNR%2FABG%2Findex.shtml&R_BW=BL&STEP=&BL=ALLE&FR=ALLE&NRBR=NR&FBEZ=FW_004&WK=ALLE&LISTE=&requestId=4642460FE1&jsMode=&letter=&WP=ALLE&listeId=4&R_WF=FR',
		'list_regex'	=> '<table class="tabelle filterLetters[^>]+>(.*)</table>',
		'person_regex'	=> '<tr [^>]+>(.*?)</tr>',
	},
	'Federal Council'	=> {
		'code'			=> 'FederalCouncil',
		'base_url'	=> 'http://www.parlament.gv.at/WWER/BR/MITGL/index.shtml?xdocumentUri=%2FWWER%2FBR%2FMITGL%2Findex.shtml&anwenden=Anwenden&BL=ALLE_BL&STEP=&FR=ALLE&NRBR=BR&FBEZ=FW_007&jsMode=&LISTE=&requestId=FE796F036A&letter=&WP=ALLE&listeId=7&R_WF=WP',
		'list_regex'	=> '<table class="tabelle filterLetters[^>]+>(.*)</table>',
		'person_regex'	=> '<tr [^>]+>(.*?)</tr>',
	},
};

# National Council:
# I session:  &R_BW=BL&anwenden=Anwenden&GP=I&STEP=&BL=ALLE&FR=ALLE&M=M&NRBR=NR&FBEZ=FW_004&WK=ALLE&jsMode=&LISTE=&requestId=D63D159187&W=W&letter=&WP=ALLE&listeId=4&R_WF=FR
# II session:      &R_BW=BL&anwenden=Anwenden&GP=II&BL=ALLE&STEP=&FR=ALLE&M=M&NRBR=NR&FBEZ=FW_004&WK=ALLE&jsMode=&LISTE=&requestId=86B694E42F&W=W&letter=&WP=ALLE&listeId=4&R_WF=FR
# II session, men: &R_BW=BL&anwenden=Anwenden&GP=II&BL=ALLE&STEP=&FR=ALLE&M=M&NRBR=NR&FBEZ=FW_004&WK=ALLE&jsMode=&LISTE=&requestId=AB07858AE4&W=&letter=&WP=ALLE&listeId=4&R_WF=FR
# 24 session, men: &R_BW=BL&anwenden=Anwenden&GP=XXIV&BL=ALLE&STEP=&FR=ALLE&M=M&NRBR=NR&FBEZ=FW_004&WK=ALLE&jsMode=&LISTE=&requestId=F59E8AAA14&W=&letter=&WP=ALLE&listeId=4&R_WF=FR
# 24 session, wom: &R_BW=BL&anwenden=Anwenden&GP=XXIV&BL=ALLE&STEP=&FR=ALLE&M=&NRBR=NR&FBEZ=FW_004&WK=ALLE&jsMode=&LISTE=&requestId=1F866E04A7&W=W&letter=&WP=ALLE&listeId=4&R_WF=FR

# Federal Council:
# base: 
# I session:	&GP=I&W=W&M=M
open my $datafh, ">", "data.tsv";
print $datafh "id\tname\tgender\timage\tbirth_date\tbirth_place\tdeath_date\tdeath_place\tgroup\thouse\tterm\tarea\texternal_links\n";
my $country = 'austria';
foreach my $chamber (keys %$chamber_data) {
	next if $chamber eq 'National Council';
	my $this_chamber_data = $chamber_data->{$chamber};
	my $chamber_code = $this_chamber_data->{code};
	foreach my $gender (keys %params_for_gender) {
		foreach my $session (@sessions) {
			my $url_to_fetch = $this_chamber_data->{base_url}."&GP=$session&$params_for_gender{$gender}";
			my $page_html = scraper::get_html("$country-$chamber_code-$session-$gender",$url_to_fetch);
			my $list = scraper::get_list($this_chamber_data->{list_regex},$page_html);
			while ($list =~ m|$this_chamber_data->{person_regex}|sg) {
				my $person = $1;
				$person =~ m|<a href="([^"]+)" ><img [^>]+>([^<]+)</a>.*?</td>.*?<td [^>]+>[^<]+<span [^>]+>([^<]+)</span>.*?</td>.*?<td.*?</td>.*?<td[^>]+>[^<]+<span title="([^"]+)"|s;
				my $data = {
					external_links	=> $1,
					name			=> $2,
					group			=> $3,
					area			=> $4,
				};
				$data->{external_links} =~ m|PAD_(\d+)|;
				$data->{id} = $1;
				$data->{gender} = $gender;
				$data->{term} = $session;
				$data->{house} = $chamber;
				$page_html = scraper::get_html("person-$data->{id}",'http://www.parlament.gv.at'.$data->{external_links});;
				$page_html =~ m|<div class="bildContainer[^>]+>\s*<a [^>]+><img alt="[^"]*" src="([^"]+)"[^>]+>.*?<p><em>Geb\.:</em> (\d\d\.\d\d\.\d{4}), ([^<]+)<br>\s*(?:<em>Verst\.:</em> (\d\d\.\d\d\.\d{4}), ([^<]+))?|s;
				($data->{image}, $data->{birth_date}, $data->{birth_place}, $data->{death_date}, $data->{death_place}) = ($1,$2,$3,$4,$5);
				$data->{external_links} = "http://www.parlament.gv.at".$data->{external_links};
				$data->{image} = "http://www.parlament.gv.at".$data->{image};
				$data->{birth_date} =~ s|\.|/|g;
				$data->{death_date} =~ s|\.|/|g;
				$data->{name} =~ s|\r\n$||;
				print $datafh "$data->{id}\t$data->{name}\t$data->{gender}\t$data->{image}\t$data->{birth_date}\t$data->{birth_place}\t$data->{death_date}\t$data->{death_place}\t$data->{group}\t$data->{house}\t$data->{term}\t$data->{area}\t$data->{external_links}\n";
			}
		}
	}
}
close $datafh;
undef;
