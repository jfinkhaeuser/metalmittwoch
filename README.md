metalmittwoch
=============

Playlist for #metalmittwoch on Google+

https://plus.google.com/s/%23metalmittwoch


structure
=========

The structure is quite simple:
`metalmittwoch/[date]` contains the playlist for the *past* wednesday
specified by the given date. The date format it `YYYY-MM-DD`.

`proposed` contains songs proposed for future #metalmittwoch events.


file formats
============

File formats are always plain UTF-8 text files. Depending on the file
extension, the expected internal structure may differ.


past events
-----------

For past #metalmittwoch events there will always be a file without file
extension that contains the playlist in human-readable form. Unindented lines
at the beginning of the file contain some metadata about the event.

What follows are lines indented by two spaces with the following format (all
separators are single spaces):
```
  ## artist - song title
```

For example, the first #metalmittwoch file looks like this:

```
#metalmittwoch #1 (Death Metal theme [with exceptions])
  01 Pantera - This love
  02 Tiamat - The Sleeping Beauty
  03 Malevolent Creation - Dominated Resurgency
  04 Cancer - Death Shall Rise
```

playlists
---------

If you want to add a playlist for some music service that contains the same
songs in the same order, add it to the appropriate date's directory. The
extension should reflect the service type, and all newly added extensions must
be documented in this README.md file.


tags
----

To be considered part of #metalmittwoch events, a post **must** contain the
`#metalmittwoch` tag. Other suggested, but not mandatory tags include:

* `#metal`
* `#metaleveryday`

Some tags have special meaning. By default, the playlist generator (see issue #7)
will ignore posts that have the #metalmittwoch tag but were not originally posted
on a specific #metalmittwoch event day. That includes posts originally posted on
non-#metalmittwoch event days, but also posts re-shared on #metalmittwoch where
the tag is also re-shared.

If you want to *force* the playlist generator to include a re-shared post, then
you can also add the `[#blutpogo](http://www.metalnews.de/cds/Teenage+Death+Explosion+-+The+Fire+Temples.7821.html)`
tag.


proposed
--------

The `proposed` file contains space indented "columns" for the artist, song title
and a proposed YouTube URL to play. The artist and song title are mandatory in
case the YouTube video gets taken down before the song can be played.
