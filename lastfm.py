#!/usr/bin/env

def collect_data(path):
  """Collect data from the metalmittwoch path."""

  def sanitize(string):
    string = string.lower()
    string = string.strip("'\" ")
    for delimiter in ('|', '(', '['):
      pos = string.find(delimiter)
      if pos > 0:
        string = string[0:pos]
    string = string.strip("'\" ")
    return string

  data = {
    'files': {}
  }
  unreadable = 0

  import re
  full_regex = re.compile(r'^ +(?P<order>\d+) +(\d+ *[-:])?(?P<band>.*?) *[-:] *(?P<track>.*) *$')
  title_regex = re.compile(r'^ +(?P<order>\d+) +(\d+ *[-:])?(?P<track>.*) *$')
  header_regex = re.compile(r'^#metalmittwoch +(?P<issue>#\d+)( +\((?P<topic>.*)\))? *$')

  import os, os.path
  for dirpath, dirnames, filenames in os.walk(path):
    for fname in filenames:
      full = os.path.join(dirpath, fname)
      data['files'][full] = {
        'items': {}
      }

      lines = file(full).readlines()

      for line in lines:
        line = line.decode('utf8')
        # Consider only those starting with >1 space followed by >1 digit
        match = full_regex.match(line)
        if not match:
          # Consider that the track might not include a band.
          match = title_regex.match(line)
          if not match:
            # Consider the line might be a header
            match = header_regex.match(line)
            if not match:
              # Spurious line
              continue
            # Keep metadata
            data['files'][full]['meta'] = match.groupdict()
            continue

        item = match.groupdict()

        # format checks/coercing
        try:
          item['order'] = int(item['order'])
          item['track'] = sanitize(item['track'])
          if item.has_key('band'):
            item['band'] = sanitize(item['band'])
          else:
            item['band'] = None
        except:
          unreadable += 1
          continue

        # Hopefully each item is now uniformly formatted so we can match
        # multiple occurrences
        data['files'][full]['items'][item['order']] = item
  data['unreadable'] = unreadable

  return data


def read_config(name):
  import ConfigParser
  config = ConfigParser.ConfigParser()
  config.read(name)

  return config


def generate_playlists(data):
  import re
  date_regex = re.compile(r'^.*/(?P<date>\d\d\d\d-\d\d-\d\d)/.*$')

  playlists = {}

  for fname, event in data['files'].items():
    match = date_regex.match(fname)
    date = None
    if match:
      date = match.groupdict()['date']

    title = '#metalmittwoch issue %s on %s' % (event['meta']['issue'], date)
    description = event['meta'].get('topic', None)
    if description:
      description = 'Special topic: %s' % description

    order = int(event['meta']['issue'][1:])

    playlists[order] = {
      'title': title,
      'description': description,
      'tracks': []
    }

    keys = event['items'].keys()
    keys.sort()

    for key in keys:
      playlists[order]['tracks'].append(event['items'][key])

  # Right, now put the playlists into a list rather than a track
  result = []
  keys = playlists.keys()
  keys.sort()

  for key in keys:
    result.append(playlists[key])

  return result



def export_playlists(network, user, local_lists):
  # Get existing lists - we might have to append to them.
  print "> Retrieving existing last.fm playlists..."
  remote_lists = user.get_playlists()

  print "> Hashing existing last.fm playlists..."
  remote_hash = {}
  for remote in remote_lists:
    remote_hash[remote.get_title()] = remote

  # Create all lists not currently existing.
  print "> Creating non-existent last.fm playlists..."
  collected = {}
  for local in local_lists:
    title = local['title']
    if remote_hash.has_key(title):
      # print '>> List "%s" already exists.' % title
      collected[title] = remote_hash[title]
    else:
      print '>> Creating list "%s"...' % title
      fmlist = network.create_new_playlist(title, local['description'])
      collected[title] = fmlist

  # Processing lists
  print "> Synchronizing list contents..."
  for local in local_lists:
    title = local['title']
    fmlist = collected[title]

    print '>> Synchronizing "%s"...' % title
    # Short-circuit on track list length. FIXME technically that's not correct,
    # but let's not complicate matters.
    remote_tracks = fmlist.get_tracks()
    remote_len = len(remote_tracks)
    local_len = len(local['tracks'])
    if remote_len >= local_len:
      continue

    for pos in range(remote_len, local_len):
      track = local['tracks'][pos]
      try:
        fmtrack = network.get_track(track['band'], track['track'])
        fmlist.add_track(fmtrack)
        fmtrack.love()
        fmtrack.add_tags(('metalmittwoch', ))
      except:
        print '>>> Could not find track "%s" by "%s" on last.fm, skipping.' % (track['track'], track['band'])


def main():
  import os, os.path
  basedir = os.getcwd()

  # Collect metalmittwoch data so far
  print "Collecting local data..."
  datadir = os.path.join(basedir, 'metalmittwoch')
  data = collect_data(datadir)

  # Read last.fm config
  print "Reading last.fm config..."
  configfile = os.path.join(basedir, 'etc', 'last.fm')
  config = read_config(configfile)

  # Generate playlists from local data
  print "Generating local playlists..."
  local_lists = generate_playlists(data)

  # Ok, connect to last.fm
  print "Connecting to last.fm..."
  import pylast
  network  = pylast.LastFMNetwork(api_key = config.get('last.fm', 'api_key'),
      api_secret = config.get('last.fm', 'api_secret'),
      username = config.get('last.fm', 'username'),
      password_hash = pylast.md5(config.get('last.fm', 'password')))

  user = network.get_user(config.get('last.fm', 'username'))

  # Export playlists to last.fm
  print "Exporting playlists..."
  export_playlists(network, user, local_lists)


if __name__ == '__main__':
  main()
