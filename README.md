# mpv-settings
basically my settings for MPV (Windows/Linux Compatible)

thats my tweaked config.
might not be suitable for your pc, but if you have any recommendations to switch stuff, just tell me.
Discord: Tsubajashi#8355

or just make a pull request if you have any recommendations, if i like it, i put it in.

# Installation
put the stuff from the zip in the "C:\Users\YOURNAME\AppData\Roaming\mpv" folder so every mpv installation of yours understands where it is.
path is different on linux, dunno where, it depends on your distro. you probably know where it is. my guess is /home/.config/mpv.
THERE IS NO DEFAULT. CHANGE YOUR DESIRED SETTINGS NAME.

# IMPORTANT
there will be many config files. select the one you think your pc can handle the best.
you need to rename the wanted config file to mpv.conf. they are currently only split into a few because i cant figure out how to let auto-profile rotate good in a cross platform enviroment.
Linux user can be calmed down, the auto rotate works for you! :)

# Youtube 4k issues
recently, i switched the ytdl format option in the high settings of mine on the high preset. if you run into issues because of slower internet, change ytdl-format to "ytdl-format='bestvideo[ext=mp4][width<=1920][height<=1080]+bestaudio[ext=m4a]'"
