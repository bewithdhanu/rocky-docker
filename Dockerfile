FROM quay.io/rockylinux/rockylinux:9

# GNOME Shell requires systemd-logind, so this image boots systemd as PID 1
ENV container=docker

# EPEL supplies novnc; GNOME, systemd and TigerVNC come from BaseOS/AppStream
RUN dnf -y install epel-release \
    && dnf -y install \
        systemd \
        dbus-x11 \
        gnome-session \
        gnome-shell \
        gnome-terminal \
        gnome-settings-daemon \
        gsettings-desktop-schemas \
        nautilus \
        adwaita-icon-theme \
        dconf \
        tigervnc-server \
        novnc \
        python3-websockify \
        mesa-dri-drivers \
        mesa-libGL \
        xorg-x11-xauth \
        xorg-x11-fonts-misc \
        xkeyboard-config \
        glibc-langpack-en \
        procps-ng \
        sudo \
        passwd \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Docker CLI only — talks to the host engine via the mounted docker.sock.
# The daemon itself is not installed; rocky sees the same containers as the host.
RUN dnf -y install dnf-plugins-core \
    && dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo \
    && dnf -y install docker-ce-cli docker-compose-plugin \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Applications: browser, office, editors, utilities, and the GNOME Software store
RUN dnf -y install \
        firefox \
        libreoffice-writer \
        libreoffice-calc \
        libreoffice-impress \
        gedit \
        evince \
        gimp \
        gnome-calculator \
        gnome-system-monitor \
        gnome-screenshot \
        gnome-disk-utility \
        gnome-tweaks \
        gnome-software \
        file-roller \
        vim-enhanced \
        git \
        wget \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Firefox decodes H.264/AAC through the system ffmpeg libraries, and Rocky ships
# none, so every MP4 — most video on the web — failed with "No video with
# supported format and MIME type found". crb is only needed to satisfy ladspa,
# a transitive dependency of the ffmpeg CLI.
RUN dnf -y --enablerepo=crb install \
        libavcodec-free \
        ffmpeg-free \
        mozilla-openh264 \
        gstreamer1-plugin-openh264 \
        gstreamer1-plugins-ugly-free \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Indian language fonts — without these, Firefox shows tofu boxes for
# Bengali, Telugu, Gujarati, Kannada, Malayalam, Punjabi, Odia, etc.
RUN dnf -y install \
        google-noto-sans-bengali-fonts \
        google-noto-sans-bengali-ui-fonts \
        google-noto-sans-devanagari-fonts \
        google-noto-sans-devanagari-ui-fonts \
        google-noto-sans-gujarati-fonts \
        google-noto-sans-gujarati-ui-fonts \
        google-noto-sans-gurmukhi-fonts \
        google-noto-sans-kannada-fonts \
        google-noto-sans-kannada-ui-fonts \
        google-noto-sans-malayalam-fonts \
        google-noto-sans-malayalam-ui-fonts \
        google-noto-sans-tamil-fonts \
        google-noto-sans-tamil-ui-fonts \
        google-noto-sans-telugu-fonts \
        google-noto-sans-telugu-ui-fonts \
        google-noto-emoji-color-fonts \
        lohit-assamese-fonts \
        lohit-bengali-fonts \
        lohit-devanagari-fonts \
        lohit-gujarati-fonts \
        lohit-gurmukhi-fonts \
        lohit-kannada-fonts \
        lohit-marathi-fonts \
        lohit-odia-fonts \
        lohit-tamil-fonts \
        lohit-telugu-fonts \
        smc-meera-fonts \
        smc-rachana-fonts \
        langpacks-core-font-hi \
        langpacks-core-font-bn \
        langpacks-core-font-te \
        langpacks-core-font-mr \
        langpacks-core-font-ta \
        langpacks-core-font-gu \
        langpacks-core-font-kn \
        langpacks-core-font-ml \
        langpacks-core-font-pa \
        langpacks-core-font-or \
        langpacks-core-font-as \
        langpacks-hi \
        langpacks-bn \
        langpacks-te \
        langpacks-mr \
        langpacks-ta \
        langpacks-gu \
        langpacks-kn \
        langpacks-ml \
        langpacks-pa \
        langpacks-or \
        langpacks-as \
    && dnf clean all \
    && rm -rf /var/cache/dnf

COPY 65-indic-prefer.conf /etc/fonts/conf.d/65-indic-prefer.conf
RUN fc-cache -f

# Tooling for the Windows-style theming step below
RUN dnf -y install \
        unzip \
        tar \
        sassc \
        glib2-devel \
        ImageMagick \
        xdotool \
        python3 \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Windows 11 look: taskbar, Start menu, Fluent theme/icons, generated wallpaper
COPY windows-look.sh /usr/local/bin/windows-look.sh
RUN chmod +x /usr/local/bin/windows-look.sh && /usr/local/bin/windows-look.sh

COPY dconf-windows-look.ini /etc/dconf/db/local.d/01-windows-look

RUN dbus-uuidgen --ensure

# GNOME misbehaves when run as root, so the desktop session belongs to a normal user.
# Password is set at container start from ROCKY_PASSWORD (default: changeme).
RUN useradd -m -s /bin/bash rocky \
    && echo 'rocky:changeme' | chpasswd \
    && usermod -aG wheel rocky \
    && mkdir -p /home/rocky/Shared /home/rocky/Documents /home/rocky/Downloads \
    && chown -R rocky:rocky /home/rocky

# Ubuntu hosts ship an AppArmor profile named "unix-chkpwd" that attaches by
# executable path, so it confines this container's copy of the helper too — even
# though the container itself is unconfined — and denies it CAP_DAC_OVERRIDE.
# Rocky's mode 000 /etc/shadow then becomes unreadable to PAM and every password
# check fails (sudo, screen unlock, polkit). Switch to the Debian layout the
# profile was written for: the helper reads /etc/shadow via group "shadow"
# instead of a capability, which works on every host.
RUN groupadd -r shadow \
    && chgrp shadow /etc/shadow \
    && chmod 0640 /etc/shadow \
    && chgrp shadow /usr/sbin/unix_chkpwd \
    && chmod 02755 /usr/sbin/unix_chkpwd

# Bind display :1 to rocky and run the X11 (not Wayland) GNOME session
RUN echo ':1=rocky' >> /etc/tigervnc/vncserver.users \
    && mkdir -p /home/rocky/.vnc \
    && printf 'session=gnome-xorg\ngeometry=1440x900\ndepth=24\n' > /home/rocky/.vnc/config \
    && chown -R rocky:rocky /home/rocky/.vnc \
    && printf 'SecurityTypes=VncAuth\n' >> /etc/tigervnc/vncserver-config-mandatory

# There is no way to unlock the screen over a passwordless VNC session
RUN mkdir -p /etc/dconf/db/local.d \
    && printf '[org/gnome/desktop/session]\nidle-delay=uint32 0\n\n[org/gnome/desktop/screensaver]\nlock-enabled=false\nidle-activation-enabled=false\n' \
        > /etc/dconf/db/local.d/00-vnc \
    && dconf update

COPY novnc.service /etc/systemd/system/novnc.service
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

RUN systemctl set-default multi-user.target \
    && systemctl enable vncserver@:1.service novnc.service \
    && systemctl mask \
        dev-hugepages.mount \
        sys-fs-fuse-connections.mount \
        systemd-remount-fs.service \
        systemd-udevd.service \
        getty.target \
        console-getty.service

ENV ROCKY_PASSWORD=changeme

EXPOSE 6080

STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/sbin/init"]
