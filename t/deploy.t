#!/usr/bin/env perl
use strict;
use Test;
use FindBin;
use lib "$FindBin::Bin/../perl/";
use Data::Dumper;

my $repobase="file:///Users/canon/Dev/gits/";
my $testrepo="kbtestserv";
my $testrepo2="kbtestserv2";
my $repohash="82e4ae592542cdeb76fa32bfebe7f3b7cf6d6567";

my $kbrt="/Applications/KBase.app/runtime/";

my $hostname=`hostname`;
chomp $hostname;

my $tdir=$FindBin::Bin;

BEGIN { plan tests => 25 }

# load your module...
use KBDeploy;

my $base="/tmp/dc.$$";
mkdir $base or die "Unable to create test directory $base";
my $tf="$base/tf.$$.out";
my $cf="$base/test.$$.ini";
my $ad="autodeploy.cfg";
my $lf="$base/dep.$$.log";

print "# Test output is in $base\n";

# Helpful notes.  All note-lines must start with a "#".
print "# I'm testing KBDeploy version $KBDeploy::VERSION\n";

# read_config
print "# Testing reading a config.\n";
my $cfg;
open(C,"> $cf");
print C "[global]\n";
print C "[defaults]\n\n";
print C "[bogus]\n";
print C "type=service\n";
print C "host=myhost\n";
close C;
ok($cfg=KBDeploy::read_config($cf));
#print Dumper($cfg);
# myservices
my @sl=KBDeploy::myservices('myhost');
ok(@sl,1);
ok(@sl[0],'bogus');

# hostlist
print "# Test hostlist\n";
my @hl=KBDeploy::hostlist();
ok(@hl,1);
ok(@hl[0],'myhost');


# Make sure things got defined
print "# Check that reading config looks okay\n";
ok(defined $cfg->{global});
ok(defined $cfg->{defaults});

#Make sure reading a config resets state
$cfg->{bogus}=1;
$cfg=KBDeploy::read_config($cf);
ok(! defined $cfg->{bogus});

# Update_config
ok(! defined $cfg->{defaults}->{bogus});
KBDeploy::update_config($cf,'defaults','bogus',1);
$cfg=KBDeploy::read_config($cf);
ok($cfg->{defaults}->{bogus},1);

# Log commands
open(LF,"> $lf");
KBDeploy::setlog(*LF);
KBDeploy::kblog("test\n");
close LF;
open(LF,$lf);
print "# setlog and kblog work\n";
ok(<LF>,"test\n");
close LF;

open(DEVNULL,">> /dev/null");
KBDeploy::setlog(*DEVNULL);


# maprepos



# Add check for undefined reponame

#
# Bogus branch
#
print "# Error if config contains a bogus branch\n";
open(C,"> $cf");
print C "[global]\n";
print C "repobase=$repobase\n";
print C "[$testrepo]\n";
print C "git-branch=bogus\n";
close C;
$cfg=KBDeploy::read_config($cf);
ok(KBDeploy::mkhashfile($tf),0);
ok(-e "$tf",undef);


#
# Detect duplicates with mismatch
#
open(C,"> $cf");
print C "[global]\n";
print C "repobase=$repobase\n";
print C "[$testrepo]\n";
print C "[$testrepo2]\n";
print C "type=lib\n";
print C "git-branch=dev\n";
print C "giturl=".$repobase."/$testrepo\n";
close C;
$cfg=KBDeploy::read_config($cf);

# Get hash for test repo
print "# tag \n";
ok(KBDeploy::gittag($testrepo));
print "# duplicate mismatch\n";
ok(KBDeploy::mkhashfile($tf),0);
ok(-e "$tf",undef);

#
# Duplicate that is okay
#
my $dc=$base."/dev_container";
open(C,"> $cf");
print C "[global]\n";
print C "repobase=$repobase\n";
print C "devcontainer=$dc\n";
print C "default-modules=\n";
print C "deploydir=$base/deployment\n";
print C "runtime=$kbrt\n";
print C "[dev_container]\n";
print C "type=lib\n";
print C "[$testrepo]\n";
print C "type=service\n";
print C "host=$hostname\n";
print C "[$testrepo2]\n";
print C "type=lib\n";
print C "giturl=".$repobase."/$testrepo\n";
close C;

# Write out a hashfile
$cfg=KBDeploy::read_config($cf);
ok(KBDeploy::mkhashfile($tf),1);

#
# Read back the hashfile
#
ok(KBDeploy::readhashes($tf));
ok(defined $cfg->{services}->{$testrepo}->{hash});

# TOD: test updatehashfile

# Test clonetag
print "# test clonetag $testrepo\n";
chdir("$base");
mkdir("$base/dev_container");
KBDeploy::clonetag($testrepo);

#This comes from update fix
ok(defined $cfg->{deployed}->{$testrepo});
ok($cfg->{deployed}->{$testrepo}->{hash},$repohash);


#
# Test read/write githash
#
my $gh="/tmp/gh.$$.out";
KBDeploy::write_githash($gh);


#
# mark complete
KBDeploy::mark_complete();
ok(-e $dc."/".$cfg->{global}->{hashfile});


# Re-read config to reset state
$cfg=KBDeploy::read_config($cf);

# is_complete
ok(KBDeploy::is_complete());

ok(!defined $cfg->{deployed}->{$testrepo});
KBDeploy::read_githash($gh);
ok(defined $cfg->{deployed}->{$testrepo});


KBDeploy::reset_complete();
ok(! -e $dc."/".$cfg->{global}->{hashfile});
ok(KBDeploy::is_complete(),0);

`rm -rf $base/$testrepo`;
`rm -rf $dc`;

KBDeploy::deploy_devcontainer($lf);
ok(-e $dc);
chdir($dc."/modules");
KBDeploy::clonetag($testrepo);
chdir($dc);

ok(KBDeploy::generate_autodeploy($ad));
ok(-e $dc.'/'.$ad);



# getdeps
# start_service
# stop_service
# test_service
# prepare_service



# auto_deploy

open(TF,"> $tf");
print TF "# 201502131300\n";
print TF "kbtestserv $repobase/kbtestserv 72715ad6d2fa474dd70417a663a4a7f328eb3fe4\n";
print TF "dev_container $repobase/dev_container 22dd0d96f9c1b96ca9ec318972c52eb70ff3d0c3\n";
close TF;

# deploy_service
print "# Run deploy_service with force\n";
ok(KBDeploy::deploy_service($tf,0,1),0);
ok(defined $cfg->{deployed}->{$testrepo});
ok($cfg->{deployed}->{$testrepo}->{hash},'72715ad6d2fa474dd70417a663a4a7f328eb3fe4');
ok($cfg->{services}->{$testrepo}->{hash},'72715ad6d2fa474dd70417a663a4a7f328eb3fe4');
ok(-e "$base/deployment/kbtestserv.log");

# update without a change
print "# run update, but nothing has changed\n";
delete $cfg->{deployed};
ok(KBDeploy::update_service($tf,0),-3);
ok($cfg->{deployed}->{$testrepo}->{hash},'72715ad6d2fa474dd70417a663a4a7f328eb3fe4');
ok($cfg->{services}->{$testrepo}->{hash},'72715ad6d2fa474dd70417a663a4a7f328eb3fe4');

#
# update_service
#
open(TF,"> $tf");
print TF "# 201502130827\n";
print TF "kbtestserv $repobase/kbtestserv 82e4ae592542cdeb76fa32bfebe7f3b7cf6d6567\n";
print TF "dev_container $repobase/dev_container 22dd0d96f9c1b96ca9ec318972c52eb70ff3d0c3\n";
close TF;
sleep 1;
print "# run update, but something has changed\n";
delete $cfg->{deployed};
ok(KBDeploy::update_service($tf,0),0);
ok(defined $cfg->{deployed}->{$testrepo});
ok($cfg->{deployed}->{$testrepo}->{hash},'82e4ae592542cdeb76fa32bfebe7f3b7cf6d6567');

#
# check_updates
#
print "# Test check_updates\n";

# Catch case where service name doesn't match repo name
open(C,"> $cf");
print C "[global]\n";
print C "devcontainer=$dc\n";
print C "repobase=$repobase\n";
print C "[defaults]\n\n";
print C "[dev_container]\n";
print C "type=lib\n";
print C "[bogus]\n";
print C "type=service\n";
print C "giturl=".$repobase."/$testrepo\n";
close C;
$cfg=KBDeploy::read_config($cf);

# Something changed
open(TF,"> $tf");
print TF "bogus $repobase/$testrepo 72715ad6d2fa474dd70417a663a4a7f328eb3fe4\n";
print TF "dev_container $repobase/dev_container 22dd0d96f9c1b96ca9ec318972c52eb70ff3d0c3\n";
close TF;
my ($status,@list)=KBDeploy::check_updates($tf);
ok($status,1);
ok($list[0],'bogus');

# Something unchanged
open(TF,"> $tf");
print TF "bogus $repobase/$testrepo 82e4ae592542cdeb76fa32bfebe7f3b7cf6d6567\n";
print TF "dev_container $repobase/dev_container 22dd0d96f9c1b96ca9ec318972c52eb70ff3d0c3\n";
close TF;
($status,@list)=KBDeploy::check_updates($tf);
ok($status,0);



# postprocess
# mkdocs


# Test running post process in fastupdate mode

# Write test for fastupdate

exit;
# Cleanup
unlink($cf);
unlink($tf);
unlink($gh);
unlink($lf);
unlink($dc."/".$cfg->{global}->{hashfile}.'.old');
`rm -rf $base/dev_container/`;
`rm -rf $base/deployment/`;
rmdir $base;
