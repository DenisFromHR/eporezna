#!/usr/bin/env perl
#
# takes "URA-exp.tab" file in the same directory
# (exported from Filemaker Pro 10)
# and generates a proper XML URA form for uploading
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


#######################################################
# declare function for finding how many days are 
# in a given month of a given year
# invoke as follows: 
# days_in_month($mon, $year)
# we use this one after reading the TAB file to find out
# how many days the report month has (for "zaglavlje")

sub days_in_month {

    30 + ($rec_month + ($rec_month > 7)) % 2 - ($rec_month == 2)
     * (2 - ($rec_year % 4 == 0 && ($rec_year % 100 != 0 || $rec_year % 400 == 0)));
} # end of days_in_month sub



# CHANGEME
# Use the name of your prepared tab-delimited file here!
$OLD="URA\-exp\.tab";
# define $NEW later, when we get report month
#$NEW="URA\_$year$mon$mday\.xml";

# open files for reading/writing
# disregard encoding, it complicates matters under Windows
#open(OLD, "<:encoding(UTF-8)", $OLD)         or die "can't open $OLD: $!";
#open(NEW, ">:encoding(UTF-8)", $NEW)         or die "can't open $NEW: $!";

open OLD, "<$OLD"         or die "can't open $OLD: $!";
# open $NEW later, when we read the file and get relevant month
#open NEW, ">$NEW"         or die "can't open $NEW: $!";


# slurp the contents of the FMPro exported TAB file into array, 
# and check number of lines (records)
# line/record contents are 12 fields:
#
#  1: $rbr  - redni broj zapisa/sloga
#  2: $br_rac - broj računa po kojem je obavljeno plaćanje
#  3: $dat_plac - datum plaćanja / rashoda
#  4: $firma - naziv firme kojoj je plaćeno
#  5: $sjediste - sjedište firme
#  6: $oib - OIB firme
#  7: $neto - neto rashod (bez PDVa)
#  8: $bruto - bruto rashod (s PDVom)
#  9: $pdv - PDV u rashodu
# - >>>> SLJEDEĆA TRI POLJA SU ISTA ZA SVE ZAPISE/SLOGOVE
# - >>>> (zbog problema s FileMakerom, koji ne dopušta izvoz zadnjeg sloga kao summary)
# 10: $sum_neto = zbroj svih neto iznosa 
# 11: $sum_bruto = zbroj svih bruto iznos
# 12: $sum_pdv = zbroj svih iznosa PDVa
# 

while(<OLD>) { 
    s/\r\n\z//; # takes care of friggin CR/LF problems - works on any system/OS
    chomp; 
    push @lines, $_; # slurp everything at once into array "@lines"
} 
close $OLD; # we're done with the exported file, get it out of the way

chomp @lines; # remove linebreaks from individual lines

$numrecs = scalar(@lines); # number of lines/records in exported TAB file
# print "Total number of lines/records: $numrecs \n"; # just checking
$firstline = $lines[0];
# let's get the relevant month for the report, we'll use the first record:
# i.e. $lines[0] (first string in @lines array) # -> changed to $firstline
$formdate = (split /\t/, $firstline)[2]; # third element of the first line
# print "formatted date from first line: \"$formdate\" \n";
$sum_neto = (split /\t/, $firstline)[9]; # tenth element of the first line
$sum_bruto = (split /\t/, $firstline)[10]; # eleventh element of the first line
$sum_pdv = (split /\t/, $firstline)[-1]; # last (twelfth) element of the first line


($rec_day, $rec_month, $rec_year) = split(/\./, $formdate);
# print "Rec. day: $rec_day, month: $rec_month, year: $rec_year \n";
# ******** > > >  $rec_month is the relevant report month < < < *****
# ******** > > >  $rec_year is the relevant report year < < < *****
# we need these to determine the number of days of the report month

# now we get the number of days in the reported month
# and invoke as: days_in_month($rec_month, $rec_year)
# using the variables we got from reading the first line, above

$numdays_mo = days_in_month($rec_month, $rec_year);
# print "Report month ($rec_month / $rec_year) has $numdays_mo days\n"; # just checking

# we now have all the required elements for URA "Zaglavlje"
# so let's prepare it for printing (perl HERE doc):

# ****************************************************************************************************
# CHANGEME: promijeniti podatke firme/obrta (ime, OIB; adresa, šifra djelatnosti, broj porezne ispostave, itd) dolje!!!!

$zaglavlje = <<"KRAJ_ZAGLAVLJA";
<?xml version="1.0" encoding="UTF-8"?>
<ObrazacURA xmlns="http://e-porezna.porezna-uprava.hr/sheme/zahtjevi/ObrazacURA/v1-0" verzijaSheme="1.0">
  <Metapodaci xmlns="http://e-porezna.porezna-uprava.hr/sheme/Metapodaci/v2-0">
    <Naslov dc="http://purl.org/dc/elements/1.1/title">Obrazac U-RA</Naslov>
    <Autor dc="http://purl.org/dc/elements/1.1/creator">PERO PERIĆ</Autor>
    <Datum dc="http://purl.org/dc/elements/1.1/date">$year-$mon-$mday\T$hour:$min:$sec</Datum>
    <Format dc="http://purl.org/dc/elements/1.1/format">text/xml</Format>
    <Jezik dc="http://purl.org/dc/elements/1.1/language">hr-HR</Jezik>
    <Identifikator dc="http://purl.org/dc/elements/1.1/identifier">$guid</Identifikator>
    <Uskladjenost dc="http://purl.org/dc/terms/conformsTo">ObrazacURA-v1-0</Uskladjenost>
    <Tip dc="http://purl.org/dc/elements/1.1/type">Elektronički obrazac</Tip>
    <Adresant>Ministarstvo Financija, Porezna uprava, Zagreb</Adresant>
  </Metapodaci>
  <Zaglavlje>
    <Razdoblje>
      <DatumOd>$rec_year-$rec_month-01</DatumOd>
      <DatumDo>$rec_year-$rec_month-$numdays_mo</DatumDo>
    </Razdoblje>
    <Obveznik>
      <OIB>XXXXXXXXXX</OIB>
      <Ime>XXXXXXXX</Ime>
      <Prezime>XXXXXXXXX</Prezime>
      <Adresa>
        <Mjesto>XXXXXXXXXX</Mjesto>
        <Ulica>ULICA XXXXXXXXX</Ulica>
        <Broj>000X</Broj>
      </Adresa>
      <PodrucjeDjelatnosti>J</PodrucjeDjelatnosti>
      <SifraDjelatnosti>XXXX</SifraDjelatnosti>
    </Obveznik>
    <ObracunSastavio>
      <Ime>XXXXXXX</Ime>
      <Prezime>XXXXXX</Prezime>
    </ObracunSastavio>
  </Zaglavlje>
  <Tijelo>
    <Racuni>
KRAJ_ZAGLAVLJA

$NEW="URA\_$rec_year\_$rec_month\_$year$mon$mday\.xml";
open NEW, ">$NEW"         or die "can't open $NEW: $!";

print NEW $zaglavlje;

# now we read al lines one by one and print out relevant records:

for $line (@lines) { # for each record, process contents
    ($rbr,$br_rac,$dat_plac,$firma,$sjediste,$oib,$neto,$bruto,$pdv,$smece1,$smece2,$smece3) = split('\t', $line);
    #print "Slog br. " . $rbr . ": datum plaćanja: " . $dat_plac . ",  neto: " . $neto ." \n";
    ($item_date, $item_month, $item_year) = split('\.', $dat_plac);
    # we again use Perl HERE doc with interpolation to print out the stuff we need
    $racun_line = <<"KRAJ_RACUNA"; 
      <R>
        <R1>$rbr</R1>
        <R2>$br_rac</R2>
        <R3>$item_year-$item_month-$item_date</R3>
        <R4>$firma</R4>
        <R5>$sjediste</R5>
        <R6>1</R6>
        <R7>$oib</R7>
        <R8>0.00</R8>
        <R9>0.00</R9>
        <R10>$neto</R10>
        <R11>$bruto</R11>
        <R12>$pdv</R12>
        <R13>0.00</R13>
        <R14>0.00</R14>
        <R15>0.00</R15>
        <R16>0.00</R16>
        <R17>$pdv</R17>
        <R18>0.00</R18>
      </R>
KRAJ_RACUNA

print NEW $racun_line;
} # end of 'for' processing of all lines

# and now the final part, again using Perl HERE doc, with interpolated variables
$zbrojevi = <<"KRAJ_URA";
    </Racuni>
    <Ukupno>
      <U8>0.00</U8>
      <U9>0.00</U9>
      <U10>$sum_neto</U10>
      <U11>$sum_bruto</U11>
      <U12>$sum_pdv</U12>
      <U13>0.00</U13>
      <U14>0.00</U14>
      <U15>0.00</U15>
      <U16>0.00</U16>
      <U17>$sum_pdv</U17>
      <U18>0.00</U18>
    </Ukupno>
  </Tijelo>
</ObrazacURA>
KRAJ_URA


print NEW "$zbrojevi\n";


# clean up and close everything
# close(OLD)     or die "can't close $OLD: $!"; # already closed above, immediately after slurping
close(NEW)      or die "can't close $NEW: $!";
