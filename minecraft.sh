#!/bin/bash

# This script launches Minecraft in splitscreen like this:

# 1. It writes an autostart file for Plasma that launches this script from within Plasma.
# 2. It starts a nested Plasma session inside Game Mode (because Game Mode cannot display multiple windows).
# 3. It launches multiple instances of Minecraft using PolyMC depending on how many controllers are connected (1-4).
# 4. It executes a KWin script that removes borders of all windows and arranges them in a grid.

export target=/tmp
cd /home/deck/.local/share/PolyMC

# writes a KWin (Steam Deck window manager) script to a file and executes it
splitScreen() {
    local pattern=$1
    splitScreenKwinScript "$pattern" > "$target/splitscreen_kwinscript"
    executeKwinScript "$target/splitscreen_kwinscript"
    rm "$target/splitscreen_kwinscript"
}

# creates a KWin script that arranges windows in a grid
splitScreenKwinScript() {
    # for debugging run "kwin_x11 --replace" in Desktop Mode before executing the script
    # inspiration from https://github.com/darkstego/Mudeer/blob/master/package/contents/code/main.js
    local pattern=$1
    cat <<____EOF
        const area = workspace.clientArea(KWin.FullScreenArea, workspace.activeWindow)

        let allWindows = workspace.stackingOrder.filter(w=>w.normalWindow && !w.skipTaskbar);
        let matchingWindows = allWindows.filter(w => w.caption.match(/$pattern/));
        let nonMatchingWindows = allWindows.filter(w => !w.caption.match(/$pattern/));

        // Minimize non-matching windows
        for (var i = 0; i < nonMatchingWindows.length; i++) {
            nonMatchingWindows[i].minimized = true;
        }

        // Calculate the number of windows per row/column
        var numWindows = matchingWindows.length;
        var numRows = Math.ceil(Math.sqrt(numWindows));
        var numCols = Math.ceil(numWindows / numRows);

        // Calculate the width and height of each window
        var windowWidth = area.width / numCols;
        var windowHeight = area.height / numRows;

        for (var i = 0; i < matchingWindows.length; i++) {
            var window = matchingWindows[i];
            var row = Math.floor(i / numCols);
            var col = i % numCols;
            var x = col * windowWidth;
            var y = row * windowHeight;
            window.noBorder = true;
            window.frameGeometry = { x: x, y: y, width: windowWidth, height: windowHeight };
        }
____EOF
}

# registers, executes and removes a given KWin script
executeKwinScript() {
    # https://gist.github.com/academo/613c8e2caf970fabd260cfd12820bde3

    # install the script
    ID=$(dbus-send --session --dest=org.kde.KWin --print-reply=literal /Scripting org.kde.kwin.Scripting.loadScript "string:$1" "string:splitscreen" | awk '{print $2}')
    # run it
    qdbus org.kde.KWin /Scripting start
    # uninstall it
    dbus-send --session --dest=org.kde.KWin --print-reply=literal /Scripting org.kde.kwin.Scripting.unloadScript "string:splitscreen" >/dev/null 2>&1
}

# takes care of launching Plasma (basically Desktop Mode) from inside Game Mode
nestedPlasma() {
    # https://gist.github.com/lucsoft/40c929537e083f1984d4dedd393eae80#file-plasmanested-sh
    unset LD_PRELOAD
    unset XDG_DESKTOP_PORTAL_DIR
    unset XDG_SEAT_PATH
    unset XDG_SESSION_PATH
    RES=$(xdpyinfo | awk '/dimensions/{print $2}')

    # Shadow kwin_wayland_wrapper so that we can pass args to kwin wrapper
    # whilst being launched by plasma-session
    sed -r 's/^        //' <<____EOF > $target/kwin_wayland_wrapper
        #!/bin/bash
        /usr/bin/kwin_wayland_wrapper --width $(echo "$RES" | cut -d 'x' -f 1) --height $(echo "$RES" | cut -d 'x' -f 2) --no-lockscreen \$@
____EOF
    chmod a+x $target/kwin_wayland_wrapper
    export PATH=$target:$PATH

    dbus-run-session startplasma-wayland
}

# writes a preset config for mcwifipnp that enables Offline Mode whenever a new Minecraft world gets created
writeOfflineModeConfig() {
    while sleep 5; do
        ls -1d instances/*/.minecraft/saves/* 2>/dev/null | while read -r world; do
            if [ ! -f "$world/mcwifipnp.json" ]; then
                cat <<________________EOF > "$world/mcwifipnp.json"
                    {
                        "port": 47283,
                        "motd": "Splitscreen",
                        "UseUPnP": false,
                        "OnlineMode": false,
                        "EnableUUIDFixer": false,
                        "CopyToClipboard": false
                    }
________________EOF
            fi
        done
    done
}

# launches Minecraft with power saving and notifications disabled and waits until a new window appears
launchGame() {
    windowCountBeforeLaunch=$(xwininfo -root -tree | grep 854x480 | wc -l)
    kde-inhibit --power --screenSaver --colorCorrect --notifications ./PolyMC-Linux-x86_64.AppImage -l "$1" -a "$2" &
    echo $! >> minecraft.pid
    # wait for the game window to appear so the order of the windows is correct
    while [ $(xwininfo -root -tree | grep 854x480 | wc -l) -le $windowCountBeforeLaunch ]; do
        sleep 1
    done
}

# launches 2-4 games in order, hides the task bar and triggers the splitScreen function when all instances are running
launchGames() {
    qdbus org.kde.plasmashell /PlasmaShell evaluateScript "panelById(panelIds[0]).hiding = 'autohide';"
    writeOfflineModeConfig &
    writeOfflineModeConfigPID=$!

    rm -f minecraft.pid
    launchGame 1.20.1-1 P1
    launchGame 1.20.1-2 P2
    [ "$numberOfControllers" -gt 2 ] && launchGame 1.20.1-3 P3
    [ "$numberOfControllers" -gt 3 ] && launchGame 1.20.1-4 P4

    qdbus org.kde.plasmashell /PlasmaShell evaluateScript "panelById(panelIds[0]).hiding = 'autohide';" # didn't always trigger the first time
    splitScreen "^Minecraft"

    wait $(<minecraft.pid)

    kill $writeOfflineModeConfigPID
    qdbus org.kde.plasmashell /PlasmaShell evaluateScript "panelById(panelIds[0]).hiding = 'none';"
    sleep 2
}

# takes care of writing an autostart entry for Plasma and calling the correct functions based on where and how this script is started
(
    echo "$(date) - Script called with $# arguments: $@"
    export numberOfControllers=$(( $(ls -1 /dev/input/js* | wc -l) / 2 )) # each one should have the real one and an emulated xbox one
    echo "Number of controllers: $numberOfControllers:"
    ls -l /dev/input/js*

    if [ "$1" = launchFromGameMode ]; then
        rm ~/.config/autostart/minecraft.desktop
        sleep 1
        launchGames
        qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
    elif xwininfo -root -tree | grep -q plasmashell; then
        launchGames
    else
        if [ "$numberOfControllers" -lt 2 ]; then
            ./PolyMC-Linux-x86_64.AppImage -l 1.20.1-1 -a P1
        else
            SCRIPT_PATH="$(readlink -f "$0")"
            mkdir -p ~/.config/autostart
            echo -e "[Desktop Entry]\nExec=\"$SCRIPT_PATH\" launchFromGameMode\nIcon=dialog-scripts\nName=Minecraft\nPath=\nType=Application\nX-KDE-AutostartScript=true" > ~/.config/autostart/minecraft.desktop
            chmod +x ~/.config/autostart/minecraft.desktop
            nestedPlasma
        fi
    fi
) >> minecraft.sh.log 2>&1
