module github.com/thomasbanghart/looker-map-layers

go 1.14

require (
	github.com/gdexlab/go-render v1.0.1
	github.com/google/go-querystring v1.0.0 // indirect
	github.com/ryankurte/go-mapbox v0.4.2
)

//point to my fork where the updates currently live
replace github.com/ryankurte/go-mapbox => github.com/thomasbanghart/go-mapbox v0.4.3-0.20200616233651-46423297ff1f
