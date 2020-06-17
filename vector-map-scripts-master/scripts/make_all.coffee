#!/usr/bin/env coffee
#
# Process various shapefiles and create mapbox tile directories for serving.
#
# This script is specific to the particular data set, with hardcoded filenames,
# feature names, and output directory, and serves mainly to document the precise
# steps that are taken to build the map files for reproducability.

require 'shelljs/global'

zip_cmd = [
  "{ __dirname }/make_vector_tiles.coffee"
  "https://s3.amazonaws.com/looker-map-tiles/source"
  "tl_2016_us_zcta510"
  "ZCTA5CE10"
].join(" ")

county_cmd = [
  "{ __dirname }/make_vector_tiles.coffee"
  "https://s3.amazonaws.com/looker-map-tiles/source"
  "tl_2016_us_county"
  "GEOID"
].join(" ")

exec zip_cmd
exec county_cmd
