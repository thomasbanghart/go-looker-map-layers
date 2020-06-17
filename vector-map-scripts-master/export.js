var geojsonvt = require("geojson-vt");
var filendir = require("filendir")
var rimraf = require("rimraf")
var geojsonextent = require("geojson-extent");
var sphericalmercator = require("sphericalmercator");
var webMercatorTiles = require("web-mercator-tiles");
var vtpbf = require('vt-pbf')
var oboe = require('oboe')
var leftPad = require('left-pad')
var fs = require('fs')

// TODO: supply these as command line arguments, along with the property key
var infile = process.argv[2];
var outfolder = process.argv[3];
var propertykey = process.argv[4];

var tileizeGeojson = function(geoJSON, outfolder) {

  var extentLL = [ -180, -90, 180, 90 ];

  console.log("extent", extentLL);

  var merc = new sphericalmercator({
      size: 256
  });

  // Convert to mercator pixel coords
  var pixels = merc.forward([extentLL[0], extentLL[1]]).concat(merc.forward([extentLL[2], extentLL[3]]));

  console.log(pixels);

  var currentZoom = 0;
  var maxZoom = 15;

  var tilesExported = 0;

  while (currentZoom <= maxZoom) {

    console.log("writing zoom " + currentZoom);

    var tileIndex = geojsonvt(geoJSON, {
      maxZoom: currentZoom,
      indexMaxZoom: currentZoom
    });

    var iterator = function(tile) {

      var tileJSON = tileIndex.getTile(tile.Z, tile.X, tile.Y);

      if (tileJSON) {
        var filename = "tiles/" + outfolder + "/" + tile.Z + "/" + tile.X + "/" + tile.Y + ".pbf";
        if (tilesExported % 1000 == 0) {
          console.log(tilesExported + " tiles exported, writing " + filename);
        }
        filendir.writeFileSync(filename, vtpbf.fromGeojsonVt({
          'geojsonLayer': tileJSON,
        }));

        tilesExported++;
      }

    }

    webMercatorTiles({
      left: pixels[0],
      bottom: pixels[1],
      right: pixels[2],
      top: pixels[3],
    }, currentZoom, iterator);

    currentZoom++;
  }

}

var writeExtentsFile = function(geoJSON, outfolder, prop) {

  console.log("processing extents...");

  var map = {};

  geoJSON.features.forEach(function(feature){
    var id = feature.properties[prop]
    map[id] = geojsonextent(feature);
  });

  console.log("writing extents file...");

  filendir.writeFileSync("tiles/" + outfolder + "/" + "extents.json", JSON.stringify(map));

  console.log("extents file written...");

}

console.log("cleaning up output folder...");

rimraf.sync("tiles/" + outfolder);

console.log("loading json...");

oboe(fs.createReadStream(infile)).done(function(json) {

  console.log("loaded json...");

  // This FIPS code thing didn't have consistent zero padding which is super lame
  // json.features.forEach(function(feature){
  //   var padded = leftPad(feature.properties["nist:fips_code"], 5, 0);
  //   feature.properties["looker:fips_padded"] = padded;
  // });

  writeExtentsFile(json, outfolder, propertykey);

  tileizeGeojson(json, outfolder);

});
