#!/usr/bin/env perl
use Dancer;
use pista;
use Device::BCM2835;

Device::BCM2835::init() || die "Could not init BCM2835 library";
dance;
