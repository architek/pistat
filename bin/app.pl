#!/usr/bin/env perl
use Dancer;
use pista;
use Device::BCM2835;

my $pid_file_name="/tmp/pistat.pid";

sub got_sig {
  unlink $pid_file_name;
  exit(0);
}

Device::BCM2835::init() || die "Could not init BCM2835 library";

open my $pid_file , ">" , $pid_file_name;
print $pid_file "$$\n";
close $pid_file;
warn "Pid is $$\n";

$SIG{QUIT} = \&got_sig;
$SIG{INT} = \&got_sig;

dance;
