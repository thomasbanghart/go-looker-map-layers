#!/usr/bin/env coffee
#
# Process tl_2016_us_county.shp file into a directory of mapbox tiles suitable
# for serving from an S3 bucket.
#
# Downloads a shapefile, creates ./tiles/DATASET.mbtiles/*
#

async = require 'artillery-async'
tmp = require 'tmp'
path = require 'path'
fs = require 'fs'
geojsonextent = require 'geojson-extent'

oboe = require 'oboe'

require 'shelljs/global'

datasetUrlBase = process.argv[2] # "https://s3.amazonaws.com/looker-map-tiles/source"
datasetName = process.argv[3] # "tl_2016_us_county"
featureName = process.argv[4] # "GEOID"

if process.argv.length != 5
  echo """
  #{ process.argv[1] } requires 3 arguments. Eg.
    #{ process.argv[1] } https://s3.amazonaws.com/looker-map-tiles/source tl_2016_us_county GEOID
  """
  exit(1)

toolDir = path.resolve "#{ __dirname }/.."
buildDir = "#{ toolDir }/tiles"
tilesDir = "#{ buildDir }/#{ datasetName }.mbtiles"

exec_step = (cmd, cb) ->
  echo cmd
  exec cmd, { async: true, silent: true }, (code, stdout, stderr) ->
    return cb("Error code #{ code } in #{ cmd }") if code > 0
    cb()

# A few variables are defined in this scope to simplify passing data between steps.
tmpDir = null
geojsonfile = null
tilesfile = null

async.series([
  (cb) ->
    # Check for existence of required tools and exit if missing.
    if not which 'ogr2ogr'
      return cb("'#{ ogr2ogr }' must be in the PATH. Try '$ brew install geos gdal'")

    if not which 'curl'
      return cb("'#{ curl }' must be in the PATH. Try '$ brew install curl'")

    for submodule in ['tippecanoe', 'mbutil']
      if not test('-d', "#{ toolDir }/#{ submodule }/")
        return cb("Cannot find '#{ toolDir }/#{ submodule }'.  Try '$ git submodule update'")

    if not test '-e', "#{ toolDir }/tippecanoe/tippecanoe"
      return cb("#{ toolDir }/tippecanoe/tippecanoe is not present. Try 'make' in #{ toolDir }/tippecanoe")
    cb()

  (cb) ->
    # Create a temporary directory and switch into it.  Remove upon exit.
    tmp.setGracefulCleanup()
    tmp.dir { template: "#{ tempdir() }/tmp-vectortiles-XXXXXX", keep: true, unsafeCleanup: true }, (err, path) ->
      if err
        cb(err)
      else
        tmpDir = path
        echo "Working in #{ tmpDir }"
        pushd tmpDir
        cb()

  (cb) ->
    cmd = "curl -O #{ datasetUrlBase }/#{ datasetName }.zip"
    exec_step cmd, cb

  (cb) ->
    # Unzip archive, expect a .shp file inside named as "#{ datasetName }.shp"
    cmd = "unzip #{ datasetName }.zip"
    exec_step cmd, cb

  (cb) ->
    geojsonfile = "#{ tmpDir }/#{ datasetName }.geojson"
    cmd = "ogr2ogr -f GeoJSON #{ geojsonfile } #{ datasetName }.shp"
    exec_step cmd, cb

  (cb) ->
    tilesfile = "#{ tmpDir }/#{ datasetName }.mbtiles"
    cmd = "#{ toolDir }/tippecanoe/tippecanoe -y #{ featureName } -z 12 --no-polygon-splitting #{ geojsonfile } -o #{ tilesfile }"
    exec_step cmd, cb

  (cb) ->
    # Ensure buildDir exists, but tilesDir must not exist
    if not test '-d', buildDir
      mkdir('-p', buildDir)
    if test '-d', tilesDir
      echo "Removing #{ tilesDir }"
      rm('-rf', tilesDir)

    # create and populate tilesDir
    cmd = "#{ toolDir }/mbutil/mb-util --image_format=pbf #{ tilesfile } #{ tilesDir }"
    exec_step cmd, cb

  (cb) ->
    # Write extents.json in the tile output dir.  Depends on tilesDir being created
    # by an earlier pipeline step.
    extentsFile = "#{ tilesDir }/extents.json"
    echo "Writing to #{ extentsFile }"

    # Use oboe to process geojsonfile incrementally, because otherwise it's easy to exhaust
    # the heap with JSON.parse() on gigabytes of data.  By discarding feature nodes after they
    # have been examined, the heap memory can be garbage-collected.
    extents = {}
    oboe(fs.createReadStream(geojsonfile)).node('!.features[*]', (feature) ->
      id = feature.properties[featureName]
      extents[id] = geojsonextent(feature)
      return oboe.drop
    ).done((finalJson) ->
      fs.writeFileSync(extentsFile, JSON.stringify(extents))
      cb()
    )

  (cb) ->
    echo "Success. Tiles and extents.json have been written to #{ tilesDir }."
    cb()

  ], (err) ->
    echo "#{ err }" if err?
    popd() if tmpDir?
    exit 1
)
