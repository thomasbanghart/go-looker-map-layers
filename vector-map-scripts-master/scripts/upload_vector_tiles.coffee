#!/usr/bin/env coffee
#
# Uploads a directory of mapbox tile files to an S3 bucket (and CloudFlare).
#
# Script mainly exists to document aws s3 cp flags for content type/encoding
# and permissions needed for public serving like a CDN.

require 'shelljs/global'
path = require 'path'

jobs = [
  #  {
  #    tilesdir: path.resolve "#{ __dirname }/tiles/tl_2016_us_county.mbtiles"
  #    bucket: "s3://looker-map-tiles/us_counties_fips_a"
  #  },
  {
    tilesdir: path.resolve "#{ __dirname }/tiles/tl_2016_zcta510.mbtiles"
    bucket: "s3://looker-map-tiles/us_zcta510"
  }
]

for job in jobs
  # Upload the tiles and the extents.json in seaprate commands, because they
  # require different --content-encoding.
  cmd = [
    'aws', 's3', 'sync',
    job.tilesdir, job.bucket,
    '--recursive',
    '--exclude extents.json',
    '--content-type=binary/octet-stream',
    '--content-encoding=gzip',
    '--grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers full=emailaddress=ben@looker.com'
  ].join(' ')
  echo cmd
  exec cmd

  cmd = [
    'aws', 's3', 'cp',
    "#{ job.tilesdir }/extents.json", "#{ job.bucket }/extents.json",
    '--grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers full=emailaddress=ben@looker.com'
  ].join(' ')
  echo cmd
  exec cmd
