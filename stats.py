#!/usr/bin/env python
#   Copyright 2012-2014 the authors (see AUTHORS).
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

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
    'items': []
  }
  unreadable = 0

  import re
  regex = re.compile(r'^ +(?P<order>\d+) +(\d+ *[-:])?(?P<band>.*?) *[-:] *(?P<track>.*) *$')

  import os, os.path
  for dirpath, dirnames, filenames in os.walk(path):
    for fname in filenames:
      full = os.path.join(dirpath, fname)

      lines = file(full).readlines()

      for line in lines:
        line = line.decode('utf8')
        # Consider only those starting with >1 space followed by >1 digit
        match = regex.match(line)
        if not match:
          continue

        item = match.groupdict()

        # format checks/coercing
        try:
          item['order'] = int(item['order'])
          item['track'] = sanitize(item['track'])
          item['band'] = sanitize(item['band'])
        except:
          unreadable += 1
          continue

        # Hopefully each item is now uniformly formatted so we can match
        # multiple occurrences
        data['items'].append(item)
  data['unreadable'] = unreadable

  return data


def get_extremes(data, key, limit = 10, top = True):
  items = {}

  # Get items and their counts
  for item in data['items']:
    if items.has_key(item[key]):
      items[item[key]] += 1
    else:
      items[item[key]] = 1

  # Sort the counts
  order = items.values()
  order.sort()
  if top:
    order.reverse()

  top = []
  while len(top) < limit:
    # Find an item with the first count, then add it to top and remove it
    # from items.
    count = order.pop(0)
    for item, c in items.items():
      if count == c:
        top.append((item, count))
        del items[item]
        break

  return top


def print_top_bands(data, limit = 10):
  # Get top bands
  top = get_extremes(data, 'band', limit, True)

  # Print
  print "Top Bands"
  print "---------"
  for index in range(0, len(top)):
    item = top[index]
    print "#%02d: %s (%d times)" % (index + 1, item[0].title(), item[1])
  print



def print_top_tracks(data, limit = 10):
  # Get top tracks
  tmp = get_extremes(data, 'track', limit, True)

  # Get band for each top track
  top = []
  for item in tmp:
    for entry in data['items']:
      if entry['track'] == item[0]:
        top.append((entry['band'], item[0], item[1]))
        break

  # Print
  print "Top Tracks"
  print "----------"
  for index in range(0, len(top)):
    item = top[index]
    print "#%02d: %s - %s (%d times)" % (index + 1, item[0].title(), item[1].title(), item[2])
  print


if __name__ == '__main__':
  import os, os.path

  basedir = os.path.join(os.path.abspath(os.getcwd()), 'metalmittwoch')
  if not os.path.isdir(basedir):
    import sys
    sys.stderr.write('Path "%s" not found or is not a directory.\n' % basedir)
    sys.exit(-1)


  data = collect_data(basedir)

  print_top_bands(data)
  print_top_tracks(data)
