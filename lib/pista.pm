use strict;
use warnings;

package pista;
use Dancer ':syntax';
use Log::Log4perl qw< :easy >;
use Dancer::Plugin::Ajax;
use File::Slurp;
use Unix::Uptime;
#use Proc::ProcessTable;
use POSIX;
use Device::BCM2835;

our $VERSION = "1.4";
my $stop=0;

set serializer => 'JSON';
set template   => 'template_toolkit';
setting log4perl => {
   tiny => 0,
   config => '
      log4perl.logger                      = ERROR, OnFile, OnScreen
      log4perl.appender.OnFile             = Log::Log4perl::Appender::File
      log4perl.appender.OnFile.filename    = debug.log
      log4perl.appender.OnFile.mode        = append
      log4perl.appender.OnFile.layout      = Log::Log4perl::Layout::PatternLayout
      log4perl.appender.OnFile.layout.ConversionPattern = [%d] [%5p] %m%n
      log4perl.appender.OnScreen           = Log::Log4perl::Appender::ScreenColoredLevels
      log4perl.appender.OnScreen.color.ERROR = bold red
      log4perl.appender.OnScreen.color.FATAL = bold red
      log4perl.appender.OnScreen.color.OFF   = bold green
      log4perl.appender.OnScreen.Threshold = ERROR
      log4perl.appender.OnScreen.layout    = Log::Log4perl::Layout::PatternLayout
      log4perl.appender.OnScreen.layout.ConversionPattern = [%d] >>> %m%n
   ',
};
setting logger => 'log4perl';

#These are the data we want to put in the table. 
my $data = [qw/loadavg ip entropy freq temp mem irq open_files open_tcp peers/];
my $gpio = [qw/3 5 7 8 10 11 12 13 15 16 18 19 21 22 23 24 26/];

my $default_refresh = 5000;

sub stop_fn {
 warn "USR1 triggered\n";
 $stop=1;
}
$SIG{USR1} = \&stop_fn;

get '/' => sub {
    my $refresh=params->{refresh} // $default_refresh;
    $refresh=1000 if $refresh<1000;
    #warning sprintf ("/: add [%s], ua [%s], ref [%s]", request->remote_address(), request->user_agent(), request->referer()); 

    template 'index',
      {
        data         => $data,
        gpio         => [map("gpio_$_",@$gpio)],
        refresh_time => $refresh,
      };
};
sub get_stats {
    my $res;
    $res->{time}    = scalar localtime;
    my $uptime= Unix::Uptime->uptime;
    my $days=$uptime/(3600*24);
    my $hours=($days-int($days))*24;
    my $minutes=($hours-int($hours))*60;
    $res->{uptime}  = sprintf("%0d " . ($days>=2?"days":"day") . " %02d hours %02d minutes",$days,$hours,$minutes);

    $res->{loadavg} = ( Unix::Uptime->load )[0];
    $res->{mem}     = join "", read_file('/proc/meminfo');
    $res->{temp} = sprintf("%8s",
      read_file('/sys/devices/virtual/thermal/thermal_zone0/temp') / 1000
      . " C");
    $res->{irq} = join "", read_file('/proc/interrupts') ;
    $res->{freq} = sprintf("%8s",read_file('/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq') / 1000 . " MHz");
#    $res->{lsusb} = join "\n", `lsusb -t`;
    my $of = read_file('/proc/sys/fs/file-nr'); my @of = split ' ', $of;
    $res->{open_files} = $of[0]-$of[1];

    $res->{entropy} = read_file('/proc/sys/kernel/random/entropy_avail');

    my @snmp=read_file('/proc/net/snmp');
    my @snmp_h=split(' ', substr($snmp[0],4));
    my @snmp_v=split(' ', substr($snmp[1],4));
    $res->{ip}=join("\n",map($snmp_h[$_] . ":" . $snmp_v[$_], 0..$#snmp_v));

#    my $ps=new Proc::ProcessTable;
#    my @top = sort { $a->pctcpu <=> $b->pctcpu } @{ $ps->table };
#    $res->{top} = join "\n" , map($top[$_]->fname,0..9);
     
     my @ot=read_file('/proc/net/tcp');
     @ot=grep(/^\s*\d/, @ot);            #only keep lines beginning with number
     $res->{open_tcp}=scalar @ot;        #number of connections
     
     @ot=map((split(' ',$_))[2],@ot);    #take only 2nd field of each line
     @ot=map(substr($_,0,8), @ot);       #and the first 8 chars
     my %seen=map{$_=>1}@ot;             #transform into a hash aka do a uniq
     delete $seen{'00000000'};           #delete some unwanted address
#    Uncomment to hide private adresses
#     for my $k (keys %seen) {
#	delete $seen{$k} if $k=~/A8C0$/ or $k=~/0A$/;   #192.168.xxxx, 10.xx
#     }
    $res->{peers}=keys %seen;
    #$res->{peers}=join("\n",keys %seen);
    get_gpio($res);
    $res->{stop}=$stop;
    if ($stop) {
	warn "Stop\n";
        $stop=0;
    } 
    $res;
}
sub get_gpio{
    my $res=shift;
    for (@$gpio) {
        $res->{"gpio_$_"} = Device::BCM2835::gpio_lev($_);
    }
}

ajax '/stats' => sub {
    get_stats;
#    error sprintf ("/stats: add [%s], ua [%s], ref [%s]", request->remote_address(), request->user_agent(), request->referer()); 
};

ajax '/config' => sub {
    error sprintf ("/config: add [%s], ua [%s], ref [%s]", request->remote_address(), request->user_agent(), request->referer()); 
    my @cpuinfo=read_file('/proc/cpuinfo');
    my ($cpuinfo) = grep /^Revision/, @cpuinfo;
    if ($cpuinfo) {
       $cpuinfo=(split(': ',$cpuinfo))[1];
    } else {
       $cpuinfo="NA";
    }
    {
	version => $VERSION,
	rev     => $cpuinfo,
        uname   => qx(uname -a),
        lversion=> read_file('/proc/version'),
        cmdline => read_file('/proc/cmdline'),
    };
};

true;
