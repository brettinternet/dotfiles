#!/bin/sh

# https://wiki.archlinux.org/title/NVIDIA_Optimus#Use_NVIDIA_graphics_only
if [ -f /etc/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf ]; then
    xrandr --setprovideroutputsource modesetting NVIDIA-0
    xrandr --auto
fi

userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

# merge in defaults and keymaps

if [ -f $sysresources ]; then
    xrdb -merge $sysresources
fi

if [ -f $sysmodmap ]; then
    xmodmap $sysmodmap
fi

if [ -f "$userresources" ]; then
    xrdb -merge "$userresources"
fi

if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
  [ -x "$f" ] && . "$f"
 done
 unset f
fi

# Load X-specific env vars & start applications
# https://wiki.archlinux.org/index.php/Xprofile
[ -f /etc/xprofile ] && . /etc/xprofile
[ -f ~/.xprofile ] && . ~/.xprofile

# e.g. startx i3
# e.g. XINIT_SESSION=xfce startx
session=${1:-$XINIT_SESSION}
case $session in
    xfce|xfce4  ) exec startxfce4 "${@:2}";;
    # i3 execs its own startup profile ~/.i3profile
    *           ) exec i3 "${@:2}";;
esac
