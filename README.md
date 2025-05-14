# About
HexConquest is a multiplayer game inspired by the classic singleplayer game HexEmpire made as a project during our studies at TCS JU.
# FAQ
## How to connect to local server?
Make sure you have rust installed
* change the const `USE_LOCAL` on top of scripts/client.gd to true 
* go to hexserver folder and run `cargo run` 
## How to run local client in the browser?
You will first need to export the project to HTML via Godot 
* In godot go to `Project/Export` and add a Web preset
* Set the export path to `build/hexconquest.html` this folder is automatically gitignored, if you make a mistake you will have to manually delete export files on git commit
* Click export all 
* Navigate to `hexgodot/build` and run 
```python3 -m http.server 8000```
* open the project in the browser on  
```http://localhost:8000/index.html```

this way you will be able to run multiple players simultanously 

