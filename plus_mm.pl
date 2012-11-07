#!/usr/bin/env perl
#
# Copyright (C) 2012 Sascha Rudolph
#
# Copryright of Google::API::Client and OAuth2::Client by
# Takatsugu Shigeta and others.
# https://github.com/comewalk/google-api-perl-client
# ------------------------------------------------------------------
use warnings;
use strict;

# [modules & such]  ------------------------------------------------
use feature qw/say/;
use lib 'lib/';

use Getopt::Std;
use FindBin;
use JSON;
use Google::API::Client;
use OAuth2::Client;

# [utf8 please] ----------------------------------------------------
binmode STDOUT, ':utf8';
binmode STDIN, ':utf8';

# [fetch & check options] ------------------------------------------
my %opts = ();
getopts('d:hi:t:', \%opts);

help() if $opts{h};

unless ($opts{d} && $opts{d} =~ /(\d{4})\-(\d\d)\-(\d\d)/) {
  say 'missing or invalid date (YYYY-MM-DD)';
  exit;
}

unless ($opts{i} && $opts{i} =~ /\d/) {
  say 'missing or invalid issue number';
  exit;
}


# [configuration] -------------------------------------------------
my $config = {
  playlist_dir => "$FindBin::Bin/metalmittwoch",
  client_secrets => "$FindBin::Bin/etc/client_secrets.json",
  api_token => "$FindBin::Bin/etc/api_token.dat",
  contributors => [
    '112287746325789895446', # jfinkhaeuser
    'me',                    # eremit
  ]
};

# [create etc if not present] --------------------------------------
mkdir "$FindBin::Bin/etc" unless -d "$FindBin::Bin/etc";

# [request data] ---------------------------------------------------
my $api_client = Google::API::Client->new;
my $service = $api_client->build('plus', 'v1');
my $oauth2 = OAuth2::Client->new_from_client_secrets($config->{client_secrets}, $service->{auth_doc});
my $api_token = get_token($config->{api_token}, $oauth2);

my $timelines = merge_timelines(
  [ map {
    $service->activities->list(body => {userId => $_, collection => 'public'})->execute({auth_driver => $oauth2});
  } @{ $config->{contributors} } ]
);

# [output processing] ----------------------------------------------
my $mm_path = $config->{playlist_dir} . '/' . $opts{d} . '/';
mkdir $mm_path unless -d $mm_path;
open my $mmfile, '>', $mm_path . 'metalmittwoch';
binmode $mmfile, ':utf8';

if (exists $opts{t}) {
  print $mmfile sprintf "#metalmittwoch #%02d (%s)\n", $opts{i}, $opts{t};
}
else {
  print $mmfile sprintf "#metalmittwoch #%02d\n", $opts{i};
}

my $postno = 1;
foreach my $post (sort { $a->{published} cmp $b->{published} } @{ $timelines }) {
  print $mmfile sprintf "  %02d %s\n", $postno, $post->{title};
  $postno++;
}

close $mmfile;

# [set token] ------------------------------------------------------
set_token($config->{api_token}, $oauth2);

# [that's it] ------------------------------------------------------
say 'finished';

exit;


# ------------------------------------------------------------------
sub help {
  say 'plus_mm - Google+ MetalMittwoch';
  say ' -d: the date that should be processed (YYYY-MM-DD)';
  say ' -i: number of issue (INTEGER)';
  say ' -h: help information';
  say ' -t: title, topic, theme information', "\n";
  say 'EXAMPLE:';
  say '  plus_mm -d 2012-10-31 -i 2 -t "Black Metal theme [with exceptions]"';
  exit;
}

sub merge_timelines {
  my $timelines = shift;
  return unless scalar @{ $timelines };
  
  my $date = $opts{d};
  my $entries = [];
  foreach my $timeline (@{ $timelines }) {
    if ($timeline && $timeline->{items} && scalar @{ $timeline->{items} }) {
      foreach my $item (@{ $timeline->{items} }) {
        next unless $item->{title} && $item->{title} =~ /#metalmittwoch/;
        next unless $item->{published} =~ /^$date/;
        next unless $item->{object};
        next unless $item->{object}{attachments} &&
          scalar @{ $item->{object}{attachments} };
        # for simplicity we assume that there is always only ONE attachment
        next unless $item->{object}{attachments}[0]{objectType} eq 'video' &&
          $item->{object}{attachments}[0]{url} =~ /youtube\.com/;
        
        push @{ $entries }, {
          title       => $item->{object}{attachments}[0]{displayName},
          youtube     => $item->{object}{attachments}[0]{url},
          contributor => $item->{actor}{displayName},
          published   => $item->{published}
        };
      }
    }
  }
  
  return $entries;
}

sub get_token {
  my ($file, $oauth2) = @_;
  my $api_token;
  if (-f $file) {
    open my $fh, '<', $file or return undef;
    {
      local $/ = undef;
      $api_token = JSON->new->decode(<$fh>);
    }
    close $fh;
    $oauth2->token_obj($api_token);
  } else {
    say 'Go to the following URI: ';
    say $oauth2->authorize_uri, "\n";

    say 'Enter verification code here:';
    my $code = <STDIN>;
    chomp $code;
    $api_token = $oauth2->exchange($code);
  }
  return $api_token;
}

sub set_token {
  my ($file, $oauth2) = @_;
  my $api_token = $oauth2->token_obj;
  open my $fh, '>', $file or return undef;
  print $fh JSON->new->encode($api_token);
  close $fh;
}
