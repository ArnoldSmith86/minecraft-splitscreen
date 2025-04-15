#!/bin/bash

# This script launches Minecraft in splitscreen like this:

# 1. It writes an autostart file for Plasma that launches this script from within Plasma.
# 2. It starts a nested Plasma session inside Game Mode (because Game Mode cannot display multiple windows).
# 3. It launches multiple instances of Minecraft using PollyMC depending on how many controllers are connected (1-4).
# 4. It executes a KWin script that removes borders of all windows and arranges them in a grid.

export target=/tmp

splitScreen() {
    splitScreenKwinScript > "$target/splitscreen_kwinscript"
    executeKwinScript "$target/splitscreen_kwinscript"
    rm "$target/splitscreen_kwinscript"
}

splitScreenKwinScript() {
    cat <<____EOF
        var workspace = workspace || {};
        var area = workspace.clientArea(0, 0, 1, 1);

        let windows = workspace.clientList().filter(w=>w.normalWindow && !w.skipTaskbar && !w.minimized);

        // Calculate the number of windows per row/column
        var numWindows = windows.length;
        var numRows = numWindows == 2 ? 1 : Math.ceil(Math.sqrt(numWindows));
        var numCols = Math.ceil(numWindows / numRows);

        // Calculate the width and height of each window
        var windowWidth = area.width / numCols;
        var windowHeight = area.height / numRows;

        for (var i = 0; i < windows.length; i++) {
            var window = windows[i];
            var row = Math.floor(i / numCols);
            var col = i % numCols;
            var x = col * windowWidth;
            var y = row * windowHeight;
            window.noBorder = true;
            window.geometry = { x: x, y: y, width: windowWidth, height: windowHeight };
        }
____EOF
}

executeKwinScript() {
    # https://gist.github.com/academo/613c8e2caf970fabd260cfd12820bde3

    # install the script
    ID=$(dbus-send --session --dest=org.kde.KWin --print-reply=literal /Scripting org.kde.kwin.Scripting.loadScript "string:$1" "string:splitscreen" | awk '{print $2}')
    # run it
    dbus-send --session --dest=org.kde.KWin --print-reply=literal "/$ID" org.kde.kwin.Script.run >/dev/null 2>&1
    # stop it
    dbus-send --session --dest=org.kde.KWin --print-reply=literal "/$ID" org.kde.kwin.Script.stop >/dev/null 2>&1
    # uninstall it
    dbus-send --session --dest=org.kde.KWin --print-reply=literal /Scripting org.kde.kwin.Scripting.unloadScript "string:splitscreen" >/dev/null 2>&1
}

nestedPlasma() {
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

launchGame() {
    rm "/home/deck/.var/app/org.fn2006.PollyMC/data/PollyMC/instances/$1/.minecraft/logs/latest.log"
    flatpak run org.fn2006.PollyMC -l "$1" -a "$2" &
    while ! grep mclanguage "/home/deck/.var/app/org.fn2006.PollyMC/data/PollyMC/instances/$1/.minecraft/logs/latest.log"; do
        sleep 1
    done
    sleep 1
}

launchGames() {
    qdbus org.kde.plasmashell /PlasmaShell evaluateScript "panelById(panelIds[0]).hiding = 'autohide';"

    launchGame 1.20.1-1 P1
    launchGame 1.20.1-2 P2
    [ "$numberOfControllers" -gt 2 ] && launchGame 1.20.1-3 P3
    [ "$numberOfControllers" -gt 3 ] && launchGame 1.20.1-4 P4

    splitScreen

    wait

    qdbus org.kde.plasmashell /PlasmaShell evaluateScript "panelById(panelIds[0]).hiding = 'none';"
    sleep 2
}

export numberOfControllers=$(( $(ls -1 /dev/input/js* | wc -l) / 2 )) # each one should have the real one and an emulated xbox one

if [ "$1" = launchFromGameMode ]; then
    rm ~/.config/autostart/minecraft.desktop
    sleep 1
    launchGames
    qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
elif [ "$1" = fromGameMode ]; then
    if [ "$numberOfControllers" -lt 2 ]; then
        flatpak run org.fn2006.PollyMC -l 1.20.1-1 -a P1
    else
        echo -e "[Desktop Entry]\nExec=$0 launchFromGameMode\nIcon=dialog-scripts\nName=sm64.sh\nPath=\nType=Application\nX-KDE-AutostartScript=true" > ~/.config/autostart/minecraft.desktop
        nestedPlasma
    fi
else
    launchGames
fi
