#!/bin/bash
cd vector-map-scripts-master
yarn install

npm install -g geojson2ndjson

cd ..

go build
	

