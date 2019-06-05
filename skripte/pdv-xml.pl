#!/usr/bin/env perl
#
# takes "PDV-exp.tab" file in the same directory
# (exported from Filemaker Pro 17)
# and generates a proper XML PDV form for uploading
# >>>>> DOES NOT use *any* modules, should work
# >>>>> with any Perl version (5.x)
#######################################################

# use warnings;

#######################################################
# first, declare function for generating GUID
# from it, we also use some date parts to name
# the output file

sub generate_guid {
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $sec = sprintf("%02d", $sec); # 2 digits
    $min = sprintf("%02d", $min); # 2 digits
    $hour = sprintf("%02d", $hour); # 2 digits
    $mday = sprintf("%02d", $mday); # 2 digits, day of the month (date)
    $mon = sprintf("%02d", $mon+1); # 2 digits, month number (01 - 12)
    $year = sprintf("%04d", $year+1900); # 4 digits
    $syear = substr($year, 2, 2); # 2 digits, the last two digits of the year
    $wday = sprintf("%02d", $wday); # 2 digits, weekday number (01 - 07)
    $yday = sprintf("%03d", $yday+1); # 3 digits, day of the year (001 - 365)
    # now the hex "mutations":
    $hyear = sprintf("%04x", $year); # get 4-place hex value from decimal
    $hsyear = sprintf("%02x", $syear); # get 2-place hex value from decimal
    $hmon = sprintf("%02x", $mon); # get 2-place hex value from decimal
    $hmday = sprintf("%02x", $mday); # get 2-place hex value from decimal
    $hhour = sprintf("%02x", $hour); # get 2-place hex value from decimal
    $hsec = sprintf("%02x", $sec); # get 2-place hex value from decimal
    $hmin = sprintf("%02x", $min); # get 2-place hex value from decimal
    #
    # GUID consists of 5 groups of characters/digits:
    # characters from "a" to "f" or digits 0-9
    # grouped as: 8chars-4chars-4chars-4chars-12chars
    #
    #let's use the following:
    # 1st group of 8 chars: $mday$mon$year
    # 2nd group, 4chars: $hsec$hmin ($sec and $min in hex notation)
    # 3rd group, 4chars: "de"+ $hmon (month - $mon in 2-digit hex notation)
    # 4th group, 4chars: "f" + $yday  (letter "f" plus day of the year, 3 digits)
    # 5th group, 12chars: $hsyear$hmon$hmday$hour$min$hsec
    #
    $myguid = "$mday$mon$year-$hsec$hmin-de$hmon-f$yday-$hsyear$hmon$hmday$hour$min$hsec";

    return $myguid;

} # end of generate_guid sub

# now we first get the GUID immediately, along with other date-related variables
# 

$guid = generate_guid(); 

# **** check if everything works as expected:
#print "Generated GUID: $guid \n";
#print "Year: " . $year . "\n";
#print "Month: " . $mon . "\n";
#print "Date: " . $mday . "\n";


# CHANGEME
# Use the name of your prepared tab-delimited file here!
$OLD="PDV\-exp\.tab";

# define $NEW later, when we get report month
#$NEW="PDV\_$year$mon$mday\.xml";

# open files for reading/writing
# disregard encoding, it complicates matters under Windows
#open(OLD, "<:encoding(UTF-8)", $OLD)         or die "can't open $OLD: $!";
#open(NEW, ">:encoding(UTF-8)", $NEW)         or die "can't open $NEW: $!";

open OLD, "<$OLD"         or die "can't open $OLD: $!";
# open $NEW later, when we read the file and get relevant month
#open NEW, ">$NEW"         or die "can't open $NEW: $!";


# slurp the contents of the FMPro exported TAB file into array, 
# WE NEED JUST THE 1st LINE!!!
# so we read just the 1st line, which contains (delimited by tabs): 
#  1: $dat_od  - (za izvješće) datum OD (početni datum) (dd.mm.)
#  2: $dat_do - (za izvješće) datum DO (završni datum) (dd.mm.)
#  3: $rep_godina - godina izvješća (YYYY)
#  4: $uk_prih_sve - ukupni prihod, XML polje <Podatak000>
#  5: $uk_devizno - ukupni devizni prihod (EU i NON-EU), <Podatak100>
#  6: $uk_devizno_EU - ukup. devizni prihod EU, <Podatak104>
#  7: $uk_devizno_NONEU - ukup. devizni prihod NON-EU, <Podatak109>
#  8: $uk_kn_prih - ukupni kunski prihod (s PDVom), <Podatak200> / <Vrijednost> = isto i za <Podatak203>
#  9: $uk_kn_prih_PDV - PDV u kunskim prihodima, <Podatak200> / <Porez> = isto i za <Podatak203>
# 10: $uk_rash = ukupni kunski rashod, <Podatak300> / <Vrijednost> = isto i za <Podatak303>
# 11: $uk_rash_PDV = PDV u kunskom rashodu, <Podatak300> / <Porez> = isto i za <Podatak303>
# 12: $uk_obveza_pdv = PDV u prodima minus PDV u rashodima, obveza, <Podatak400>
# 13: $pdv_kredit = višak/manjak iz prethodnih razdoblja, <Podatak500>
# 14: $pdv_za_uplatu = svega za platiti, <Podatak600>
# PAZI - ako je polje 14 minus, onda skinuti minus i staviti ga bez minusa u XML <Predujam>
# $prefix = substr($pdv_za-uplatu, 0, 1); # prvi znak
#  if $prefix eq "-" then $novi_pdv_kredit = substr $pdv_za_uplatu, 1; # remove minus, declare new (positive) value as new PDV credit

while(<OLD>) { 
    s/\r\n\z//; # takes care of friggin CR/LF problems - works on any system/OS
    chomp; 
    push @lines, $_; # slurp everything at once into array "@lines"
} 
close $OLD; # we're done with the exported file, get it out of the way

chomp @lines; # remove linebreaks from individual lines

$firstline = $lines[0];
# let's get the relevant elements from the first line for the report:
($dat_od, $dat_do, $rep_godina, $uk_prih_sve, $uk_devizno, $uk_devizno_EU, $uk_devizno_NONEU, $uk_kn_prih, $uk_kn_prih_PDV, $uk_rash, $uk_rash_PDV, $uk_obveza_pdv, $pdv_kredit, $pdv_za_uplatu) = (split /\t/, $firstline);

$dat_od = (split /\t/, $firstline)[0]; # first element of the first line
$dat_do = (split /\t/, $firstline)[1]; # second element of the first line
$rep_godina = (split /\t/, $firstline)[2]; # 3rd element of the first line
$uk_prih_sve = (split /\t/, $firstline)[3]; # 4th element of the first line
    if ($uk_prih_sve eq "") { $uk_prih_sve = "0.00"}; # if empty, then define as zero
$uk_devizno = (split /\t/, $firstline)[4]; # 5th element of the first line
    if ($uk_devizno eq "") { $uk_devizno = "0.00"}; # if empty, then define as zero
$uk_devizno_EU = (split /\t/, $firstline)[5]; # 6th element of the first line
    if ($uk_devizno_EU eq "") { $uk_devizno_EU = "0.00"}; # if empty, then define as zero
$uk_devizno_NONEU = (split /\t/, $firstline)[6]; # 7th element of the first line
    if ($uk_devizno_NONEU eq "") { $uk_devizno_NONEU = "0.00"}; # if empty, then define as zero
$uk_kn_prih = (split /\t/, $firstline)[7]; # 8th element of the first line
    if ($uk_kn_prih eq "") { $uk_kn_prih = "0.00"}; # if empty, then define as zero
$uk_kn_prih_PDV = (split /\t/, $firstline)[8]; # 9th element of the first line
    if ($uk_kn_prih_PDV eq "") { $uk_kn_prih_PDV = "0.00"}; # if empty, then define as zero
$uk_rash = (split /\t/, $firstline)[9]; # 10th element of the first line
    if ($uk_rash eq "") { $uk_rash = "0.00"}; # if empty, then define as zero
$uk_rash_PDV = (split /\t/, $firstline)[10]; # 11th element of the first line
    if ($uk_rash_PDV eq "") { $uk_rash_PDV = "0.00"}; # if empty, then define as zero
$uk_obveza_pdv = (split /\t/, $firstline)[11]; # 12th element of the first line
    if ($uk_obveza_pdv eq "") { $uk_obveza_pdv = "0.00"}; # if empty, then define as zero
$pdv_kredit = (split /\t/, $firstline)[12]; # 13th element of the first line
    if ($pdv_kredit eq "") { $pdv_kredit = "0.00"}; # if empty, then define as zero
$pdv_za_uplatu = (split /\t/, $firstline)[13]; # 14th element of the first line

# above also checks all fields which might be empty and sets them to zero ("0.00")

# 14: $pdv_za_uplatu = svega za platiti, <Podatak600>
# PAZI - ako je polje 14 minus, onda skinuti minus i staviti ga bez minusa u XML <Predujam>
# ako NIJE minus, onda je novi kredit = "0.00"
$prefix = substr($pdv_za_uplatu, 0, 1); # first char
if ($prefix eq "-") { # tj. ako je prvi znak minus
    $novi_pdv_kredit = substr($pdv_za_uplatu, 1); # onda je novi PDV kredit taj iznos, ali bez minusa
} else {
    $novi_pdv_kredit = "0.00" # inače je novi PDV kredit nula
}


# get proper report dates and month
$repdd_od = (split /\./, $dat_od)[0]; # first element of the string split on dot (i.e. "dd")
$repmonth = (split /\./, $dat_od)[1]; # second element of the string split on dot (i.e. "mm")
$repdd_do = (split /\./, $dat_do)[0]; # first element of the string split on dot (i.e. "dd")
# $rep_godina već imamo od ranije, u formatu yyyy

# 14: $pdv_za_uplatu = svega za platiti, <Podatak600>
# PAZI - ako je polje 14 minus, onda skinuti minus i staviti ga bez minusa u XML <Predujam>
# ako NIJE minus, onda je novi kredit = "0.00"
$prefix = substr($pdv_za_uplatu, 0, 1); # first char
if ($prefix eq "-") { # tj. ako je prvi znak minus
    $novi_pdv_kredit = substr($pdv_za_uplatu, 1); # onda je novi PDV kredit taj iznos, ali bez minusa
    $povrat = "True";
} else {
    $povrat = "False";
}



# we now have all the required elements for PDV XML report
# so let's prepare it for printing (perl HERE doc):

# CHANGEME: promijeniti podatke firme/obrta (ime, OIB; adresa, broj porezne ispostave, itd) dolje!!!!

$PDVreport = <<"KRAJ";
<?xml version="1.0" encoding="UTF-8"?>
<ObrazacPDV xmlns="http://e-porezna.porezna-uprava.hr/sheme/zahtjevi/ObrazacPDV/v9-0" verzijaSheme="9.0">
	<Metapodaci xmlns="http://e-porezna.porezna-uprava.hr/sheme/Metapodaci/v2-0">
		<Naslov dc="http://purl.org/dc/elements/1.1/title">Prijava poreza na dodanu vrijednost</Naslov>
		<Autor dc="http://purl.org/dc/elements/1.1/creator">XXXXXXX XXXXXXX;</Autor>
		<Datum dc="http://purl.org/dc/elements/1.1/date">$year-$mon-$mday\T$hour:$min:$sec</Datum>
		<Format dc="http://purl.org/dc/elements/1.1/format">text/xml</Format>
		<Jezik dc="http://purl.org/dc/elements/1.1/language">hr-HR</Jezik>
		<Identifikator dc="http://purl.org/dc/elements/1.1/identifier">$guid</Identifikator>
		<Uskladjenost dc="http://purl.org/dc/terms/conformsTo">ObrazacPDV-v9-0</Uskladjenost>
		<Tip dc="http://purl.org/dc/elements/1.1/type">Elektronički obrazac</Tip>
		<Adresant>Ministarstvo Financija, Porezna uprava, Zagreb</Adresant>
	</Metapodaci>
	<Zaglavlje>
		<Razdoblje>
			<DatumOd>$rep_godina-$repmonth-$repdd_od</DatumOd>
			<DatumDo>$rep_godina-$repmonth-$repdd_do</DatumDo>
		</Razdoblje>
		<Obveznik>
			<Ime>XXXXXXXXXX</Ime>
			<Prezime>XXXXXXXXX</Prezime>
			<OIB>XXXXXXXXXX</OIB>
			<Adresa>
				<Mjesto>XXXXXXX</Mjesto>
				<Ulica>ULICA XXXXXXXX</Ulica>
				<Broj>000X</Broj>
			</Adresa>
		</Obveznik>
		<ObracunSastavio>
			<Ime>XXXXXXXXX</Ime>
			<Prezime>XXXXXXXXXXXXX</Prezime>
		</ObracunSastavio>
		<Ispostava>XXXXXX</Ispostava>
		<Napomena></Napomena>
	</Zaglavlje>
	<Tijelo>
		<Podatak000>$uk_prih_sve</Podatak000>
		<Podatak100>$uk_devizno</Podatak100>
		<Podatak101>0.00</Podatak101>
		<Podatak102>0.00</Podatak102>
		<Podatak103>0.00</Podatak103>
		<Podatak104>$uk_devizno_EU</Podatak104>
		<Podatak105>0.00</Podatak105>
		<Podatak106>0.00</Podatak106>
		<Podatak107>0.00</Podatak107>
		<Podatak108>0.00</Podatak108>
		<Podatak109>$uk_devizno_NONEU</Podatak109>
		<Podatak110>0.00</Podatak110>
		<Podatak200>
			<Vrijednost>$uk_kn_prih</Vrijednost>
			<Porez>$uk_kn_prih_PDV</Porez>
		</Podatak200>
		<Podatak201>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak201>
		<Podatak202>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak202>
		<Podatak203>
			<Vrijednost>$uk_kn_prih</Vrijednost>
			<Porez>$uk_kn_prih_PDV</Porez>
		</Podatak203>
		<Podatak204>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak204>
		<Podatak205>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak205>
		<Podatak206>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak206>
		<Podatak207>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak207>
		<Podatak208>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak208>
		<Podatak209>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak209>
		<Podatak210>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak210>
		<Podatak211>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak211>
		<Podatak212>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak212>
		<Podatak213>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak213>
		<Podatak214>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak214>
		<Podatak215>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak215>
		<Podatak300>
			<Vrijednost>$uk_rash</Vrijednost>
			<Porez>$uk_rash_PDV</Porez>
		</Podatak300>
		<Podatak301>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak301>
		<Podatak302>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak302>
		<Podatak303>
			<Vrijednost>$uk_rash</Vrijednost>
			<Porez>$uk_rash_PDV</Porez>
		</Podatak303>
		<Podatak304>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak304>
		<Podatak305>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak305>
		<Podatak306>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak306>
		<Podatak307>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak307>
		<Podatak308>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak308>
		<Podatak309>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak309>
		<Podatak310>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak310>
		<Podatak311>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak311>
		<Podatak312>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak312>
		<Podatak313>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak313>
		<Podatak314>
			<Vrijednost>0.00</Vrijednost>
			<Porez>0.00</Porez>
		</Podatak314>
		<Podatak315>0.00</Podatak315>
		<Podatak400>$uk_obveza_pdv</Podatak400>
		<Podatak500>$pdv_kredit</Podatak500>
		<Podatak600>$pdv_za_uplatu</Podatak600>
		<Podatak700>0.00</Podatak700>
		<Podatak810>0.00</Podatak810>
		<Podatak811>0.00</Podatak811>
		<Podatak812>0.00</Podatak812>
		<Podatak813>0.00</Podatak813>
		<Podatak814>0.00</Podatak814>
		<Podatak815>0.00</Podatak815>
		<Podatak820>0.00</Podatak820>
		<Podatak830>0.00</Podatak830>
		<Podatak831>
			<Vrijednost>0.00</Vrijednost>
			<Broj>0</Broj>
		</Podatak831>
		<Podatak832>
			<Vrijednost>0.00</Vrijednost>
			<Broj>0</Broj>
		</Podatak832>
		<Podatak833>
			<Vrijednost>0.00</Vrijednost>
			<Broj>0</Broj>
		</Podatak833>
		<Podatak840>0.00</Podatak840>
		<Podatak850>0.00</Podatak850>
		<Podatak860>0.00</Podatak860>
		<Podatak870>true</Podatak870>
KRAJ

# sada provjera ima li PDV kredita: ako ima, 
# dodaje još i redak "<Predujam>"" pred kraj
if ($povrat eq "True") {
    $POVRAT_report_end = <<"END_REPT";
    	<Predujam>$novi_pdv_kredit</Predujam>
	</Tijelo>
</ObrazacPDV>
END_REPT
} else { # ako nema novog PDV kredita, redak "<Povrat>" se izostavlja
    $POVRAT_report_end = <<"END_REPT";
	</Tijelo>
</ObrazacPDV>
END_REPT
}


$NEW="PDV\_$rep_godina\_$repmonth\_$year$mon$mday\.xml";
open NEW, ">$NEW"         or die "can't open $NEW: $!";

print NEW $PDVreport . $POVRAT_report_end;


# clean up and close everything
close(NEW)      or die "can't close $NEW: $!";
