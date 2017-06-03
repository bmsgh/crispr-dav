#!/usr/bin/env perl
# Creates html page
# Author: X. Wang

use strict;
use File::Basename;
use Getopt::Long;
use File::Path qw(make_path);
use FindBin qw($Bin);

my $usage = "Usage: $0 [option] indir outdir
	--ref     <str> reference name, e.g. hg19. Required.	
	--gene    <str> Gene name, e.g. FPR2. Required.
	--region  <str> a bed file of amplicon. Required.
	--crispr  <str> a bed file containing sgRNA region. Required.
	--cname   <str> Name of CRISPR site. Optional. 
	--nocx    Do not to create canvasXpress alignment view 
	--high_res	High resolution tiff image was created.	
	indir	input directory where result files (e.g. plot image files) are. 
	outdir	output directory 
";
my %h;
GetOptions( \%h, 'ref=s', 'region=s', 'crispr=s', 'gene=s', 'cname=s', 'nocx',
    'high_res' );

die $usage if ( @ARGV != 2 );
my ( $indir, $outdir ) = @ARGV;
die "Missing required argument."
  if ( !$h{ref}
    or !$h{region}
    or !$h{gene}
    or !$h{crispr} );

my $ref  = $h{ref};
my $gene = $h{gene};
my ( $amp_chr, $amp_start, $amp_end, $amp_name, $amp_seq, $amp_strand ) =
  getTarget( $h{region} );
my ( $chr, $start, $end, $site_name, $seq, $strand, $hdr ) =
  getTarget( $h{crispr}, $h{cname} );
die "Incorrect crispr name $h{cname}.\n"
  if ( $h{cname} && $h{cname} ne $site_name );

## set up assets
my $sitedir = "$outdir/$site_name";
make_path($sitedir);
qx(cp $Bin/assets/* $sitedir/assets);

## find samples
my @samples = getSamples( $indir, $site_name );
my $rowsep = scalar(@samples) > 10 ? "</tr><tr>" : "";

# create web page
my $page = "$sitedir/index.html";
open( my $fh, ">$page" ) or die $!;
my $rc_tog = getToggleLink("rc");         ## read count
my $pp_tog = getToggleLink( "pp", 1 );    ## preprocessing

my $plot_ext = $h{high_res} ? "tif" : "png";

print $fh "<html lang='en'>
	<head>
		<meta charset='utf-8'>
		<script src=assets/crispr.js></script>
	<body>
		<h2>Gene: $gene</h2><p>
		<table border=1 cellpadding=0 cellspacing=0 style='border-collapse:collapse' width=800>
			<tr align=center><th>Region</th><th>Reference Version</th><th>Chr</th>
				<th>Start</th><th>End</th><th>Strand</th><th>CRISPR Sequence</th>
				<th>HDR Base Changes on + Strand</th></tr>
			<tr align=center><td>Amplicon</td><td>$ref</td><td>$amp_chr</td>
				<td>$amp_start</td><td>$amp_end</td><td>$amp_strand</td><td></td>
				<td></td></tr>
			<tr align=center><td>$site_name</td><td>$ref</td><td>$chr</td>
				<td>$start</td> <td>$end</td><td>$strand</td><td>$seq</td>
				<td>$hdr</td></tr>
		</table>
		<div id='high_res' style='display:none'>$h{high_res}</div>
		<p><b>Read Counts and Percentages at CRISPR Site:</b>$rc_tog
		<table><tr>
			<td><img src=assets/$site_name.indelcnt.$plot_ext /></td>$rowsep
			<td><img src=assets/$site_name.indelpct.$plot_ext /></td>
		</tr></table>
		</div>

		<!--select box for individual sample-->
		<p><b>Charts for individual sample</b>
		<select id='select1' onchange='showCharts(\"$site_name\")'>
			<option value=''>Select a sample to view</option>
";

foreach my $s (@samples) {
    print $fh "<option value=\'$s\'>$s</option>";
}
print $fh "</select>
	<p id='charts'></p>
	<p><b>Preprocessing of Reads: </b>$pp_tog
	<table><tr>
		<td><img src=assets/$site_name.readcnt.$plot_ext></td>$rowsep
		<td><img src=assets/$site_name.readchr.$plot_ext></td>
	</tr></table>
	</div>
";

## categories with each plot for individual sample
my %category_header = (
    "len" => "Indel Length at CRISPR Site",
    "cov" => "Amplicon Coverage",
    "ins" => "Insertion Locations in Amplicon",
    "del" => "Deletion Locations in Amplicon",
    "snp" => "SNP Locations around CRISPR Site"
);

my @cats = ( "cov", "ins", "del", "len", "snp" );
foreach my $cat (@cats) {
    my $tab = getCategoryTable( $cat, $plot_ext );
    my $tog = getToggleLink( $cat, 1 );
    print $fh "<p><b>$category_header{$cat}:</b>$tog\n$tab</div>\n\n";
}

## HDR chart
if ($hdr) {
    my $hdr_tog = getToggleLink( "hdr", 1 );
    print $fh "
	<p><b>Homology Directed Repair Rates: </b>$hdr_tog
		<table>
		<tr><tr><td>When categorizing oligo types, the region from the first to the last base 
			change was examined.</td></tr>
        <tr><td>Non-Oligo: None of the intended base changes occurs, regardless of indel.</td></tr>
        <tr><td>Partial Oligo: Some but not all intended base changes occur, and no indel.</td></tr>
        <tr><td>Edited Oligo: One or more intended base changes occur, and there is indel(s).</td></tr>
		<tr><td>Perfect Oligo: All intended base changes occur, but no indel.</td></tr>
		<tr>
			<td><img src=assets/$site_name.hdr.$plot_ext /></td>$rowsep
		</tr>
		</table>
	</div>
";
}

## Allele alignment view
if ( !$h{nocx} ) {
    print $fh "<p><b>Visual Alignment of Indel Alleles</b><p>\n
	  <a href=${site_name}_cx1.html>Alleles with indel &ge; 1%</a><br>\n
	  <a href=${site_name}_cx0.html>All Alleles</a>\n";
}

## Spreadsheet data
print $fh "<p><b>Spreadsheet data:</b><p>
	<table>
		<tr><td><a href=assets/${site_name}_cnt.xlsx>Read stats</a></td></tr>
		<tr><td><a href=assets/${site_name}_pct.xlsx>Indel summary</a></td></tr>
		<tr><td><a href=assets/${site_name}_len.xlsx>Allele data</a></td></tr>
		<tr><td><a href=assets/${site_name}_snp.xlsx>SNP data</a></td></tr>
";

if ($hdr) {
    print $fh
      "<tr><td><a href=assets/${site_name}_hdr.xlsx>HDR data</a></td></tr>";
}

print $fh "</table></body></html>";
close $fh;

## return a category's html table of assets of all samples
# input: extension of plots, like len.png for length distribution plot
sub getCategoryTable {
    my ( $cat, $plot_ext ) = @_;
    my $i     = 0;
    my $CELLS = $cat eq "snp" ? 1 : 2;    # number of cells per row
    my $tab   = "<table border=0>";
    foreach my $s (@samples) {
        my $img = "$sitedir/assets/$s.$site_name.$cat.$plot_ext";
        next if !-f $img;
        if ( $i % $CELLS == 0 ) {
            $tab .= "</tr>" if ($i);
            $tab .= "<tr>";
        }

        $tab .= "<td><img src=assets/$s.$site_name.$cat.$plot_ext></td>";
        $i++;
    }
    $tab .= "</tr>" if ( $tab !~ /<\/tr>$/ );
    $tab .= "</table>";
    return $tab;
}

# name is in 4th column
sub getTarget {
    my ( $bedfile, $name ) = @_;
    die "Cannot find $bedfile\n" if !-f $bedfile;

    ### Only the first coordinate entry is used.
    open( F, $bedfile ) or die "cannot open target file $bedfile\n";
    my $line;
    while ( $line = <F> ) {
        next if ( $line =~ /^\#/ or $line !~ /\w/ );
        chomp $line;
        my @a = split( /\s+/, $line );
        if ( !$name or $a[3] eq $name ) {
            last;
        }
    }
    close F;

    return split( /\s+/, $line );  # (chr, start, end, name, score, strand, hdr)
}

## find samples of this CRISPR site
sub getSamples {
    my ( $indir, $site_name ) = @_;
    my @samples;
    foreach my $f ( glob("$indir/*.$site_name.pct") ) {
        basename($f) =~ /(.*)\.${site_name}\.pct$/;
        push( @samples, $1 );
    }
    die "No sample data for $site_name\n" if !@samples;
    return sort @samples;
}

sub getToggleLink {
    my ( $sn, $hide ) = @_;

    # section name, like: pp --preprocessing
    # hide: 1 or 0

    my $fname = $hide ? "plus.jpg" : "minus.jpg";
    my $style = $hide ? "none"     : "block";

    my $str =
      "<a href=\"javascript:hideshow(\'$sn.div\');toggleImg(\'$sn.img\')\">";
    $str .= "<img src=assets/$fname width=15 height=15 id=\'$sn.img\'></a>";
    $str .= "\n<div id=\"$sn.div\" style=\"display:$style\">";
    return $str;
}
