go-looker-map-layers: 
	cd vector-map-scripts-master
	yarn install
	npm install -g geojson2ndjson
	cd ..
	rm yarn*
	rm -r node_modules
	go build
	

