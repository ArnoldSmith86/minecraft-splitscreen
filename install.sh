#!/bin/bash
targetDir=$HOME/.local/share/PolyMC

curlProgress() {
    if [ ! -f "$3" ]; then
        echo "📦 Downloading $2"

        curl -L --progress-bar "$4" -o "$3"

        if md5sum "$3" | grep -q $1; then
            echo -e "\033[1A\r\033[K\033[1A\r\033[K✅ $2 download complete and verified"
        else
            echo -e "\033[1A\r\033[K\033[1A\r\033[K❌ $2 download failed"
            rm -f "$3"
            fail "A download failed. Try to run the script again. If it persists, report the problem on GitHub."
        fi
    else
        echo "✅ $2 already present."
    fi
}

fail() {
    echo -e "\n\n❌ $1\n"
    zenity --error --text="$1"
    exit 1
}

if [ ! -d "$targetDir" ]; then
    [ $(df /home | awk '$6 == "/home" { print $4 }') -lt 2000000 ] && fail 'Please make sure you have at least 2GB available on the internal storage.'
    zenity --question --text='This script will download the PolyMC launcher, install a few mods for making Splitscreen work and add Minecraft to Steam.\n\nInstall it?' || exit 1
fi

mkdir -p $targetDir
pushd $targetDir >/dev/null

    curlProgress 9b5849c657738799469ab7517ab36baf \
                 PolyMC \
                 PolyMC-Linux-x86_64.AppImage \
                 https://github.com/PolyMC/PolyMC/releases/download/7.0/PolyMC-Linux-7.0-x86_64.AppImage
    chmod +x "PolyMC-Linux-x86_64.AppImage"

    if [ ! -f "jdk-17.0.12/bin/java" ]; then
        curlProgress e8df6a595078d41b993a71ed55e503ab \
                     Java \
                     jdk-17.0.12_linux-x64_bin.tar.gz \
                     https://download.oracle.com/java/17/archive/jdk-17.0.12_linux-x64_bin.tar.gz
        echo -n "📦 Extracting Java"
        if ! (tar xzf jdk-17.0.12_linux-x64_bin.tar.gz && rm jdk-17.0.12_linux-x64_bin.tar.gz); then
            echo -e "\r\033[K❌ Extracting Java failed"
            rm -rf jdk-17.0.12_linux-x64_bin.tar.gz jdk-17.0.12
            fail 'Extracting Java failed.'
        else
            echo -e "\r\033[K✅ Java extracted"
        fi
    else
        echo "✅ Java already present."
    fi

    if [ ! -f polymc.cfg ]; then
        # create polymc.cfg
        sed 's/^            //' <<________EOF > polymc.cfg
            [General]
            ApplicationTheme=system
            ConfigVersion=1.2
            FlameKeyShouldBeFetchedOnStartup=false
            IconTheme=pe_colored
            JavaPath=jdk-17.0.12/bin/java
            Language=en_US
            LastHostname=$HOSTNAME
            MaxMemAlloc=4096
            MinMemAlloc=512
            UseNativeOpenAL=true
________EOF
    fi

    # create the 4 game instances
    for i in {1..4}; do
        mkdir -p "instances/1.20.1-$i/.minecraft/mods" "instances/1.20.1-$i/.minecraft/config"
        pushd "instances/1.20.1-$i" >/dev/null

            if [ ! -f ".minecraft/mods/framework-forge-1.20.1-0.7.12.jar" ]; then
                # download framework
                if [ -f "../1.20.1-1/.minecraft/mods/framework-forge-1.20.1-0.7.12.jar" ]; then
                    cp "../1.20.1-1/.minecraft/mods/framework-forge-1.20.1-0.7.12.jar" ".minecraft/mods/framework-forge-1.20.1-0.7.12.jar"
                else
                    curlProgress 1b6b6ccc60c5a6ef2c232553f8a060f4 \
                                 'Framework Mod' \
                                 .minecraft/mods/framework-forge-1.20.1-0.7.12.jar \
                                 https://mediafilez.forgecdn.net/files/5911/986/framework-forge-1.20.1-0.7.12.jar
                fi
            fi

            if [ ! -f ".minecraft/mods/controllable-forge-1.20.1-0.21.7-release.jar" ]; then
                # download controllable
                if [ -f "../1.20.1-1/.minecraft/mods/controllable-forge-1.20.1-0.21.7-release.jar" ]; then
                    cp "../1.20.1-1/.minecraft/mods/controllable-forge-1.20.1-0.21.7-release.jar" ".minecraft/mods/controllable-forge-1.20.1-0.21.7-release.jar"
                else
                    curlProgress 54a8852b383aa35ccbe773f00dafe944 \
                                 'Controllable Mod' \
                                 .minecraft/mods/controllable-forge-1.20.1-0.21.7-release.jar \
                                 https://raw.githubusercontent.com/ArnoldSmith86/minecraft-splitscreen/refs/heads/main/controllable-forge-1.20.1-0.21.7-release.jar
                fi
            fi

            if [ ! -f ".minecraft/mods/mcwifipnp-1.7.3-1.20.1-forge.jar" ]; then
                # download mcwifipnp
                if [ -f "../1.20.1-1/.minecraft/mods/mcwifipnp-1.7.3-1.20.1-forge.jar" ]; then
                    cp "../1.20.1-1/.minecraft/mods/mcwifipnp-1.7.3-1.20.1-forge.jar" ".minecraft/mods/mcwifipnp-1.7.3-1.20.1-forge.jar"
                else
                    curlProgress e742cacdecc43586e7ef2e0e724ef923 \
                                 'LAN World Plug-n-Play Mod' \
                                 .minecraft/mods/mcwifipnp-1.7.3-1.20.1-forge.jar \
                                 https://cdn.modrinth.com/data/RTWpcTBp/versions/r19tuFwp/mcwifipnp-1.7.3-1.20.1-forge.jar
                fi
            fi

            if [ ! -f ".minecraft/options.txt" ]; then
                echo -e "onboardAccessibility:false\nskipMultiplayerWarning:true\ntutorialStep:none" > .minecraft/options.txt
                if [ "$i" -gt 1 ]; then
                    echo "soundCategory_music:0" >> .minecraft/options.txt
                fi
            fi

            if [ ! -f ".minecraft/servers.dat" ]; then
                echo -ne '\n\0\0\x09\0\x07servers\n\0\0\0\x01\x08\0\x02ip\0\x0f127.0.0.1:47283\x08\0\x04name\0\x0bSplitscreen\0\0' > .minecraft/servers.dat
            fi

            if [ ! -f ".minecraft/config/controllable-client.toml" ]; then
                # create controllable-client.toml
                sed 's/^                    //' <<________________EOF > ".minecraft/config/controllable-client.toml"
                    [client]
                    [client.options]
                    autoSelectIndex = $((i-1)).0
________________EOF
            fi

            if [ ! -f "instance.cfg" ]; then
                # create config.json
                sed 's/^                    //' <<________________EOF > "instance.cfg"
                    [General]
                    ConfigVersion=1.2
                    InstanceType=OneSix
                    JavaPath=jdk-17.0.12/bin/java
                    OverrideJavaLocation=true
                    iconKey=default
                    name=1.20.1-$i
________________EOF
            fi

            if [ ! -f "mmc-pack.json" ]; then
                # create components.json
                sed 's/^                    //' <<________________EOF > "mmc-pack.json"
                    {
                        "components": [
                            {
                                "cachedName": "LWJGL 3",
                                "cachedVersion": "3.3.1",
                                "cachedVolatile": true,
                                "dependencyOnly": true,
                                "uid": "org.lwjgl3",
                                "version": "3.3.1"
                            },
                            {
                                "cachedName": "Minecraft",
                                "cachedRequires": [
                                    {
                                        "suggests": "3.3.1",
                                        "uid": "org.lwjgl3"
                                    }
                                ],
                                "cachedVersion": "1.20.1",
                                "important": true,
                                "uid": "net.minecraft",
                                "version": "1.20.1"
                            },
                            {
                                "cachedName": "Forge",
                                "cachedRequires": [
                                    {
                                        "equals": "1.20.1",
                                        "uid": "net.minecraft"
                                    }
                                ],
                                "cachedVersion": "47.4.0",
                                "uid": "net.minecraftforge",
                                "version": "47.4.0"
                            }
                        ],
                        "formatVersion": 1
                    }
________________EOF
            fi

        popd >/dev/null
    done

    if [ ! -f "accounts.json" ]; then
        # create accounts.json
        sed 's/^            //' <<________EOF > accounts.json
            {
                "accounts": [
                    {
                        "active": true,
                        "entitlement": {
                            "canPlayMinecraft": true,
                            "ownsMinecraft": true
                        },
                        "profile": {
                            "capes": [
                            ],
                            "id": "99f7b67dff4a3921ab1855d7abaafc82",
                            "name": "P1",
                            "skin": {
                                "id": "",
                                "url": "",
                                "variant": ""
                            }
                        },
                        "type": "Offline",
                        "ygg": {
                            "extra": {
                                "clientToken": "bf6cb3d6c80d4448a932522de4a51d51",
                                "userName": "P1"
                            },
                            "iat": 1745307597,
                            "token": "0"
                        }
                    },
                    {
                        "entitlement": {
                            "canPlayMinecraft": true,
                            "ownsMinecraft": true
                        },
                        "profile": {
                            "capes": [
                            ],
                            "id": "45c6ab0a786e3272b6806c93ba62c2b4",
                            "name": "P2",
                            "skin": {
                                "id": "",
                                "url": "",
                                "variant": ""
                            }
                        },
                        "type": "Offline",
                        "ygg": {
                            "extra": {
                                "clientToken": "878b7cd9a9e34505b64efde6ce1f9470",
                                "userName": "P2"
                            },
                            "iat": 1745307602,
                            "token": "0"
                        }
                    },
                    {
                        "entitlement": {
                            "canPlayMinecraft": true,
                            "ownsMinecraft": true
                        },
                        "profile": {
                            "capes": [
                            ],
                            "id": "ac4e5ee749823b818186f0480155d43d",
                            "name": "P3",
                            "skin": {
                                "id": "",
                                "url": "",
                                "variant": ""
                            }
                        },
                        "type": "Offline",
                        "ygg": {
                            "extra": {
                                "clientToken": "de836a1d55a448e091cf21ed2800bf1a",
                                "userName": "P3"
                            },
                            "iat": 1745307605,
                            "token": "0"
                        }
                    },
                    {
                        "entitlement": {
                            "canPlayMinecraft": true,
                            "ownsMinecraft": true
                        },
                        "profile": {
                            "capes": [
                            ],
                            "id": "35b0aa2bc5633d5b9f98490635965826",
                            "name": "P4",
                            "skin": {
                                "id": "",
                                "url": "",
                                "variant": ""
                            }
                        },
                        "type": "Offline",
                        "ygg": {
                            "extra": {
                                "clientToken": "5d36c1ee9be04fe8a0d256cbbd3af3d2",
                                "userName": "P4"
                            },
                            "iat": 1745307609,
                            "token": "0"
                        }
                    }
                ],
                "formatVersion": 3
            }
________EOF
    fi

    # download the launch wrapper
    rm -f minecraft.sh
    curlProgress 7ebf79bf258ff75d03cfa1074198ef1a \
                 'Launch script' \
                 minecraft.sh \
                 https://raw.githubusercontent.com/ArnoldSmith86/minecraft-splitscreen/refs/heads/main/minecraft.sh
    chmod +x minecraft.sh

    # add the launch wrapper to Steam
    if ! grep -q local/share/PolyMC/minecraft ~/.steam/steam/userdata/*/config/shortcuts.vdf; then
        rm -f add-to-steam.py
        curlProgress 3426e204f94575d63e9ed40cb4603d02 \
                     'Shortcut creation script' \
                     add-to-steam.py \
                     https://raw.githubusercontent.com/ArnoldSmith86/minecraft-splitscreen/refs/heads/main/add-to-steam.py
        echo -n '⏳ Shutting down Steam in order to add the Minecraft shortcut'
        steam -shutdown
        while pgrep -F ~/.steam/steam.pid >/dev/null; do
            echo -n .
            sleep 1
        done
        [ -f shortcuts-backup.vdf ] || cp ~/.steam/steam/userdata/*/config/shortcuts.vdf shortcuts-backup.vdf
        if python add-to-steam.py >/dev/null; then
            echo -e "\r\033[K✅ Shortcut added to Steam (if your shortcuts broke, there's a backup at $(pwd)/shortcuts-backup.vdf)"
        else
            echo -e "\r\033[K❌ Adding shortcut failed (if your shortcuts broke, there's a backup at $(pwd)/shortcuts-backup.vdf)"
            nohup steam >/dev/null 2>&1 &
            fail 'Adding shortcut to Steam failed.'
        fi
    fi
popd >/dev/null

if zenity --question --icon-name=dialog-ok --text='No errors. Go back to Game Mode and start Minecraft.\n\nGo to Game Mode now?'; then
    qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
elif ! pgrep -F ~/.steam/steam.pid >/dev/null; then
    nohup steam >/dev/null 2>&1 &
fi

# END OF FILE
