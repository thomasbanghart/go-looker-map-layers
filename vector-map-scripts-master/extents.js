var geojsonStream = require("geojson-stream");
var geojsonextent = require("geojson-extent");
var fs = require('fs')
var es = require('event-stream')
var filendir = require("filendir")

var infile = process.argv[2];
var outfile = process.argv[3];
var propertykey = process.argv[4];

if (!infile || !outfile || !propertykey) {
  console.log("Not enough parameters:\nyarn run extents <input geojson path> <output json path> <property key>");
  return;
}

var map = {};

console.log("Parsing features for key " + propertykey + "...");

var s = geojsonStream.parse();
s.on('data', function(feature){
    var id = feature.properties[propertykey];
    map[id] = geojsonextent(feature);
});
fs.createReadStream(infile).pipe(s).pipe(es.through(null, function (data) {

  console.log("writing extents file...");

  filendir.writeFileSync(outfile, JSON.stringify(map));

  console.log("extents file written...");

}));

