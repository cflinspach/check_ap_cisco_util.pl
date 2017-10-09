#!/usr/bin/perl
# About: Check plugin for nagios/icinga to check utilization of Cisco AP's
# 
# Usage: 
#
# Version 1.0
# Author: Casey Flinspach
#         cflinspach@protonmail.com
#
#################################################################################

use strict;
use warnings;
use Net::SNMP;
use Getopt::Long qw(:config no_ignore_case);
use List::MoreUtils qw(pairwise);
use Net::Ping;

my $hostaddr = '';
my $community = '';
my $ap_tx_util_oid = '';
my $ap_rx_util_oid = '';
my $ap_name_oid = '';

GetOptions(
		"help|h-" => \my $help,
        "Host|H=s" => \$hostaddr,
        "community|C=s" => \$community,
        "ap_tx_util_oid|t=s" => \$ap_tx_util_oid,
        "ap_rx_util_oid|r=s" => \$ap_rx_util_oid,
        "ap_name_oid|O=s" => \$ap_name_oid);

if($help) {
        help();
        exit;
}


sub help { print "
About: Check plugin for nagios/icinga to record utilization of Cisco AP's. 

Currently does not have warning or critical thresholds and is used primarily to gather data for graphs.

Usage:
check_ap_cisco_util.pl -H [host] -C [community] -O [ap name oid] -r [ap receive oid] -t [ap transmit oid]

Meru example:
check_ap_cisco_util.pl -H 192.168.0.6 -C public -O .1.3.6.1.4.1.14179.2.2.1.1.3 -r .1.3.6.1.4.1.14179.2.2.13.1.2 -t .1.3.6.1.4.1.14179.2.2.13.1.1

";
}

my ($session, $error) = Net::SNMP->session(
                        -hostname => "$hostaddr",
                        -community => "$community",
                        -timeout => "30",
                        -version => "2c",
                        -port => "161");

if (!defined($session)) {
        printf("ERROR: %s.\n", $error);
        help();
        exit 1;
}

my $ap_tx_util = $session->get_table( -baseoid => $ap_tx_util_oid );
my $ap_rx_util = $session->get_table( -baseoid => $ap_rx_util_oid );
my $ap_name = $session->get_table( -baseoid => $ap_name_oid);

if (! defined $ap_tx_util || ! defined $ap_rx_util || ! defined $ap_name ) {
    die "ERROR: " . $session->error;
    $session->close();
}

my @ap_tx_name_array;
my @ap_rx_name_array;
foreach my $ap_name_key (keys %$ap_name) {
	push(@ap_tx_name_array,"'$ap_name->{$ap_name_key} out:'" );
    push(@ap_rx_name_array,"'$ap_name->{$ap_name_key} in:'" );
}

my @ap_tx_util_array;
foreach my $ap_tx_util_key (keys %$ap_tx_util) {
	next if $ap_tx_util_key =~ /.1$/;
	push(@ap_tx_util_array,$ap_tx_util->{$ap_tx_util_key});
}

my @ap_rx_util_array;
foreach my $ap_rx_util_key (keys %$ap_rx_util) {
        next if $ap_rx_util_key =~ /.1$/;
        push(@ap_rx_util_array,$ap_rx_util->{$ap_rx_util_key});
}


my $err = $session->error;
if ($err){
        print $err;
        return 1;
}

my @tx_results;
my @rx_results;
print "OK Utilization counts | ";
foreach my $i (0 .. $#ap_tx_name_array) {
	if (defined $ap_tx_util_array[$i]) {
		push (@tx_results, "$ap_tx_name_array[$i]=$ap_tx_util_array[$i] ");
	}
}
foreach my $i (0 .. $#ap_rx_name_array) {
	if (defined $ap_tx_util_array[$i]) {
		push (@tx_results, "$ap_rx_name_array[$i]=$ap_rx_util_array[$i] ");
	}
}
print @tx_results;
print @rx_results;
print "\n";
$session->close();
exit 0;
