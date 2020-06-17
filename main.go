package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"

	mapbox "github.com/ryankurte/go-mapbox/lib"
)

const username string = "wilg-looker"

func printUsage() {
	fmt.Println("USAGE: ./looker-mapbox-layer upload|create tilesetID [path/to/upload/geojson]")
	os.Exit(1)

}

func uploadTileset(mapBox *mapbox.Mapbox, path string) {
	// Upload the geojson to mapbox
	extentsCh := make(chan int)
	go makeExents(mapBox, path, extentsCh)
	newlinePath, err := newlineGeoJSON(path)
	if err != nil {
		fmt.Println(err)
		return
	}
	req, err := mapBox.Tilesets.UploadGeoJSON(newlinePath)
	fmt.Printf("Uploading to Mapbox... might take a moment...\n\n")
	if err != nil {
		fmt.Println(err)
		return
	}
	//Print out the ID for the recipe.json file
	fmt.Println(req.ID)
	fmt.Println("Update the tileset-recipe.json file with the above id...")
	if <-extentsCh > 0 {
		fmt.Println("Check that extents file -- something went wrong")
	}

	return

}

func newlineGeoJSON(path string) (string, error) {
	cmd := fmt.Sprintf("geojson2ndjson %s > ../newline.json", path)
	newline := exec.Command("bash", "-c", cmd)
	_, err := newline.Output()
	if err != nil {
		return "", err
	}
	return "./newline.json", nil
}

func makeExents(mapBox *mapbox.Mapbox, path string, extentsCh chan int) {
	os.Chdir("./vector-map-scripts-master")
	cmd := exec.Command("pwd")
	stdout, err := cmd.Output()
	fmt.Println(string(stdout))

	if err != nil {
		extentsCh <- 1
		return
	}
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Please enter the feature key for the extents file: ")
	featureKey, _ := reader.ReadString('\n')
	cmd = exec.Command("yarn", "run", "extents", path, "../extents.json", featureKey)
	fmt.Println(cmd)
	stdout, err = cmd.Output()
	if err != nil {
		fmt.Println(string(stdout))
		extentsCh <- 1
		return
	}
	fmt.Println("Extents file complete")
	extentsCh <- 0

}

func createTileset(mapBox *mapbox.Mapbox) {
	req, err := mapBox.Tilesets.CreateTileset("./tileset-recipe.json")
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println(*req)

}

func publishTileset(mapBox *mapbox.Mapbox) {
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
