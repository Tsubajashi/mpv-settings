# mpv-settings
my settings for MPV (Windows/Mac/Linux Compatible)

might not be suitable for your pc, but if you have any recommendations, just tell me, 
or just make a pull request. If i like it, i put it in.

# Documentation
Here goes all information about scripts and upscaler used. (WIP)

# List of Scripts used in my mpv-settings:

- Mac_Integration.lua - This script enables a few shortcuts which Mac users are familiar with. See scripts/Mac_Integration.lua for more infos.
- acompressor.lua - a simple audio compression script which can normalize your audio of the files played with mpv. See scripts/acompressor.lua for more infos.
- appendURL.lua - when mpv is opened, you can copy paste a URL in to play from.
- audio-osc.lua - different on screen controls for audio-only playback.
- autoload.lua - preloads all files in a folder into a playlist.
- seek-to.lua - when "t" is pressed, you can seek to a specific part of the video/audio you are currently watching.
- youtube-quality.lua - if ctrl+f is pressed, you can switch the different resolutions of a youtube video if played back through mpv.

# Installation
Depending on your Operating System, you need to place the stuff inside the zip in a certain directory.
The root directory needs to look like this (Should be considered a Tree View example):


>Roaming

>>mpv

>>input.conf

>>mpv.conf

>>>shaders

>>>script-opts

>>>scripts

you need to rename the proper config you want to use to mpv.conf.

example: mpv-windows.conf -> mpv.conf

# WINDOWS INSTALLATION
> "C:\Users\ %Username% \AppData\Roaming\mpv"

# MAC INSTALLATION
Path:

/USERNAME/.config/mpv

Tested Apple Devices on latest OS (BigSur at the time of writing the readme):

- Base Macbook Pro 2018 13"
- Macbook Air M1 8Cpu/8Gpu


# LINUX INSTALLATION
Path:
/home/user/.config/mpv

/user/ is always the name of the user who wants to use mpv.

# Community and Discord Help Server

I also have a Server for mpv-settings and AIO_Video_Enhancer. You can join here: https://discord.gg/WjtkbcQ

Discord: Tsubajashi#8355

# DONATIONS
if you like to donate, heres a link: https://paypal.me/tsubajashi
I always thank anybody who donates to me, as the current time is a bit rough when it comes to my finances, but don't pressure yourself to do so.
It's a donation after all - if you are in a similar bad spot financially, please use it to get yourself nice things. :)
i also released a patreon if you want to support me on a monthly basis, its a "pay what you want" patreon as i dont have scheduled releases. https://www.patreon.com/tsubajashi
