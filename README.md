# mpv-settings
basically my settings for MPV (Windows/Linux/Mac Compatible) (i think)

thats my tweaked config.
might not be suitable for your pc, but if you have any recommendations to switch stuff, just tell me.
Discord: Tsubajashi#8355

or just make a pull request if you have any recommendations, if i like it, i put it in.

# Installation
Depending on your Operating System, you need to place the stuff inside the zip in a certain directory, except if you are an mac user (refer to "MAC INSTALLATION").
The root directory needs to look like this:

->mpv

-->input.conf

-->mpv.conf

--->Shaders

--->script-opts

--->scripts


# Windows Path
"C:\Users\YOURNAME\AppData\Roaming\mpv"

# Linux Path
/home/USERNAME/.config/mpv

# MAC INSTALLATION
Path:

/USERNAME/.config/mpv


The Issue: 

macOS is only compatible with some shaders (no compute shader support), and is limited to opengl output(and an old feature set at that). thats why if you want to install the config on a mac, delete "mpv.conf" and rename "mpv-mac.conf" to "mpv.conf". this is a special version of my config for macs/macbooks.
Tested Apple Devices:

- Base Macbook Pro 2018 13"
