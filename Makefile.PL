use inc::Module::Install;

name 'Pistat';
all_from 'lib/pista.pm';
author q{Laurent KISLAIRE <teebeenator@gmail.com>};
license 'perl';

build_requires 'Test::More';
requires 'Dancer' => '0';
requires 'Log::Log4perl' => '0';
requires 'Dancer::Logger::Log4perl' => '0';
requires 'File::Slurp' => '0';
requires 'Unix::Uptime' => '0';
#requires 'Device::BCM2835' => '0';
requires 'Template' => '0';
requires 'YAML' => '0';

test =>
  { TESTS => q[t/001_base.t 002_index_route.t] };

auto_install;

WriteAll;

