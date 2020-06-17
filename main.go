package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"runtime"

	mapbox "github.com/ryankurte/go-mapbox/lib"
)

const username string = "wilg-looker"

func printUsage() {
	fmt.Println("USAGE: ./looker-mapbox-layer upload|create tilesetID [path/to/upload/geojson]")
	os.Exit(1)

}

func uploadTileset(mapBox *mapbox.Mapbox, _path string) {
	//upload the geojson to mapbox
	reader := bufio.NewReader(os.Stdin)

	//prompt for feature key
	fmt.Print("Please enter the feature key for the extents file: ")
	featureKey, _ := reader.ReadString('\n')

	//set up channel to make extents while file uploads
	extentsCh := make(chan int)
	go makeExents(mapBox, _path, extentsCh, featureKey)

	//turn geoJSON into newline geoJSON
	err := newlineGeoJSON(_path)
	if err != nil {
		log.Fatal(err)
		return
	}

	//get path to calling directory to keep things happy and hit upload
	_, filename, _, _ := runtime.Caller(1)
	filepath := path.Join(path.Dir(filename), "/newline.json")
	req, err := mapBox.Tilesets.UploadGeoJSON(filepath)
	fmt.Printf("Uploading to Mapbox... might take a moment...\n\n")
	if err != nil {
		log.Fatal(err)
		return
	}

	//print out the ID for the recipe.json file
	fmt.Println(req.ID)
	fmt.Println("Update the tileset-recipe.json file with the above id...")

	//wait for exents creation to finish before returning
	if <-extentsCh > 0 {
		fmt.Println("Check that extents file -- something went wrong")
	}

	return

}

func newlineGeoJSON(path string) error {
	//runs a handy npm package to create newline geoJSON -- needed for Mapbox API
	cmd := fmt.Sprintf("geojson2ndjson %s > ../newline.json", path)

	//redirection using > is a bash specific call
	newline := exec.Command("bash", "-c", cmd)
	_, err := newline.Output()
	if err != nil {
		return err
	}
	return nil
}

func makeExents(mapBox *mapbox.Mapbox, path string, extentsCh chan int, featureKey string) {
	//have to use "yarn run" within the directory and write to main directory
	os.Chdir("./vector-map-scripts-master")
	cmd := exec.Command("yarn", "run", "extents", path, "../extents.json", featureKey)
	stdout, err := cmd.Output()
	if err != nil {
		log.Fatal(string(stdout))
		extentsCh <- 1
		return
	}
	fmt.Println("Extents file complete")
	extentsCh <- 0

}

func createTileset(mapBox *mapbox.Mapbox) {
	//create a tileset for the sources page on Mapbox
	req, err := mapBox.Tilesets.CreateTileset("./tileset-recipe.json")
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println(*req)

}

func publishTileset(mapBox *mapbox.Mapbox) {
	//Publish the tileset
	req, err := mapBox.Tilesets.PublishTileset()
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Printf("Success: %s", *req)
	mapBox.Tilesets.CheckJobStatus()

}

func main() {
	if len(os.Args) < 3 {
		printUsage()
	}
	args := os.Args[1:]
	token := os.Getenv("MAPBOX_ACCESS_TOKEN")

	//Create new mapbox instance
	mapBox, err := mapbox.NewMapbox(token)
	if err != nil {
		log.Fatal(err)
	}
	command := args[0]
	tilesetID := args[1]

	//Populate it with id and username for tileset
	mapBox.Tilesets.SetTileset(username, tilesetID)

	//switch to handle command line args
	switch command {
	case "upload":
		if len(args) < 3 {
			fmt.Println("I need a path to the geojson file wrapped in \"\"")
			return
		}
		path := args[2]
		uploadTileset(mapBox, path)
	case "create":
		createTileset(mapBox)
	case "publish":
		publishTileset(mapBox)
	default:
		printUsage()
	}

}
