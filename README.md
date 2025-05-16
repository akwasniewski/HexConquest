# About
HexConquest is a multiplayer game inspired by the classic singleplayer game HexEmpire made as a project during our studies at TCS JU.
# FAQ
## How to connect to local server?
Make sure you have rust installed
* change the const `USE_LOCAL` on top of scripts/client.gd to true 
* go to hexserver folder and run `cargo run` 
## How to run local client in the browser?
First chceck if you have export templates. Than you need to export the project to HTML via Godot.
* go to editor tab in godot and go to Manage Export Templates
* install mirror
* Make a folder build in hexgodot (set gitignore)
* In godot go to `Project/Export` and add a Web preset
* Set the export path to `build/hexconquest.html`
* Click export project
* Navigate to `hexgodot/build` and run 
```python3 -m http.server 8000```
* open the project in the browser on  
```http://localhost:8000/hexconquest.html```

this way you will be able to run multiple players simultanously in different tabs

