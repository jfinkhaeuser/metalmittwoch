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
use Data::Dumper;

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
};

# [create etc if not present] --------------------------------------
mkdir "$FindBin::Bin/etc" unless -d "$FindBin::Bin/etc";

# [request data] ---------------------------------------------------
my $api_client = Google::API::Client->new;
my $service = $api_client->build('plus', 'v1');
my $oauth2 = OAuth2::Client->new_from_client_secrets($config->{client_secrets}, $service->{auth_doc});
my $api_token = get_token($config->{api_token}, $oauth2);


my $timelines = [];
my $nextPageToken = undef;
my $result = undef;
my $skipped = 0;
my $processed = 0;
do {
  if (defined $nextPageToken) {
    $result = $service->activities->search(body => { query => '#metalmittwoch', maxResults => 20, pageToken => $nextPageToken })->execute({auth_driver => $oauth2});
  }
  else {
    $result = $service->activities->search(body => { query => '#metalmittwoch', maxResults => 20 })->execute({auth_driver => $oauth2});
  }
  $nextPageToken = $result->{nextPageToken};

  ($result, $skipped, my $p) = filter_results($result->{items});
  $processed += $p;
  if (scalar @{ $result }) {
    push $timelines, $result;
  }
} while (scalar @{ $result } || $skipped);

say 'Found ', $processed, ' entries matching #metalmittwoch in total.';

if (!defined $timelines || !scalar @{ $timelines }) {
  die "Could not retrieve any posts for the given date";
}

$timelines = merge_timelines($timelines);

if (!defined $timelines || !scalar @{ $timelines}) {
  die "No entries left after merging";
}

say 'Found ', scalar @{ $timelines }, ' entries matching the current date.';

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
my $youtube = {};
foreach my $post (sort { $a->{published} cmp $b->{published} } @{ $timelines }) {
  # avoid double entries in the list
  next if $youtube->{$post->{youtube}};
  $youtube->{$post->{youtube}} = 1;
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

sub filter_results {
  my $results = shift;
  return unless scalar @{ $results };

  my $entries = [];

  my $skipped = 0;
  my $processed = 0;

  use DateTime;
  use DateTime::Format::RFC3339;
  use DateTime::Format::Builder;

  my $strdate = $opts{d};
  my $date = DateTime::Format::Builder->create_parser( strptime => '%Y-%m-%d' );
  $date = $date->parse( 'DateTime::Format::Builder', $strdate );

  my $rfc_parser = DateTime::Format::RFC3339->new;

  foreach my $item (@{ $results }) {
    ++$processed;

    if (not $item->{published} =~ /^$strdate/) {
      # If we have the published date, we're all good. If not, we need to
      # distinguish between older and newer events.
      # - If we do not find any entries matching the date because they're
      #   all older, we're fine; we need to stop paginating.
      # - If we do not find any entries matching the date because they're
      #   all newer, we set $skipped (i.e. we need to continue paginating)
      # - If a page contains older, matching and newer events, we can safely
      #   set $skipped for newer events. The processing order will be from
      #   newest to oldest, that is, one old event will overwrite $skipped.
      my $published = $rfc_parser->parse_datetime($item->{published});
      my $delta = $date->subtract_datetime($published);
      if ($delta->is_negative()) {
        # We found events newer than $date
        $skipped = 1;
      }
      next;
    }

    next unless $item->{object};
    next unless $item->{object}{content} && $item->{object}{content} =~ /#metalmittwoch/;
    next unless $item->{object}{attachments} &&
      scalar @{ $item->{object}{attachments} };
    # for simplicity we assume that there is always only ONE attachment
    my $valid = {'video' => 1, 'article' => 1};
    next unless exists $valid->{$item->{object}{attachments}[0]{objectType}} &&
      $item->{object}{attachments}[0]{url} =~ /youtube\.com/;

    push @{ $entries }, {
      title       => $item->{object}{attachments}[0]{displayName},
      youtube     => $item->{object}{attachments}[0]{url},
      contributor => $item->{actor}{displayName},
      published   => $item->{published}
    };
  }

  return $entries, $skipped, $processed;
}

sub merge_timelines {
  my $timelines = shift;
  return unless scalar @{ $timelines };

  my $date = $opts{d};
  my $entries = [];

  foreach my $timeline (@{ $timelines }) {
    if ($timeline && scalar @{ $timeline }) {
      foreach my $item (@{ $timeline }) {
        push @{ $entries }, $item;
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
