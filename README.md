# Minecraft Splitscreen for Steam Deck

A script to run multiple instances of Minecraft in splitscreen mode on Steam Deck using PolyMC and KDE Plasma.

## Features

- Automatically detects connected controllers
- Supports 1-4 players
- Removes window borders
- Arranges windows in a grid layout
- Works with Game Mode

## Installation

Download [InstallMinecraft.desktop](https://github.com/ArnoldSmith86/minecraft-splitscreen/releases/download/0.1/InstallMinecraft.desktop) with your Steam Deck in Desktop Mode and open it in the file browser Dolphin.

It should:
- Download PolyMC and Java 17
- Create 4 Minecraft 1.20.1 instances with a pre-configured Controllable mod so each instance can be controlled using a different controller
- Create 4 offline accounts in PolyMC
- Download my launch wrapper that starts four Minecraft instances in a splitscreen configuration from Game Mode
- Shutdown Steam in order to add the launch wrapper to Steam with artwork from steamgriddb.com
- Restart Steam (still in Desktop Mode)

Note that personally, I'm using [Steam-Deck.Auto-Disable-Steam-Controller](https://github.com/scawp/Steam-Deck.Auto-Disable-Steam-Controller) to disable the internal Steam Deck controller whenever an external controller is connected. You might have to rearrange controller order or change the controller index in Controllable if you don't use it.

## Usage

Start Minecraft from Game Mode.

The script will:
1. Detect connected controllers
2. Launch appropriate number of Minecraft instances
3. Arrange windows in splitscreen
4. Remove window borders

To link the instances:
1. In the first instance (P1), start a singleplayer world
2. Open the world to LAN (Esc > Open to LAN)
3. In other instances, go to Multiplayer and join the LAN game

## Troubleshooting

While testing the installation, sometimes the instances could not connect to the LAN server. Restarting the Steam Deck completely seemed to help. No idea what's going on there.

## Notes

- The first launch takes quite a while because it's downloading all the assets
- On my TV, I set Minecraft to do 1440p in the Game Mode settings and I set UI scale to 3 so that the crafting table and its recipes fit next to each other

## License

MIT License - see LICENSE file for details 