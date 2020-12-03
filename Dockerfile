# =================================================================
# INIT: Import the root filesystem.
# Later, we can use ARG + ENV to build for any arm64 device:
# https://archlinuxarm.org/platforms/armv8
# =================================================================

# Start with SOS base image
FROM docker.io/faddat/sos-base

MAINTAINER jacobgadikian@gmail.com

# =================================================================
# OS: This is where we set up the operating system.
# =================================================================

# Set System Locale
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
		 locale-gen
ENV LC_ALL en_US.UTF-8


# Don't check disk space because we are in a container
RUN sed -i -e "s/^CheckSpace/#!!!CheckSpace/g" /etc/pacman.conf


# FINISH GETTING PACMAN TO LIFE
# Get and install rpi 4 kernel
RUN	pacman-key --init && \
		pacman-key --populate archlinuxarm && \
		pacman-db-upgrade && \
		pacman -R --noconfirm openssh linux-aarch64 uboot-raspberrypi && \
		curl -LJO https://github.com/Biswa96/linux-raspberrypi4-aarch64/releases/download/5.4.72-1/linux-raspberrypi4-aarch64-5.4.72-1-aarch64.pkg.tar.xz && \
		curl -LJO https://github.com/Biswa96/linux-raspberrypi4-aarch64/releases/download/5.4.72-1/linux-raspberrypi4-aarch64-headers-5.4.72-1-aarch64.pkg.tar.xz && \
		pacman -U --noconfirm *.tar.xz && \
		rm *.tar.xz
		pacman --noconfirm -Syyu \
				archlinux-keyring \
				ca-certificates \
				ca-certificates-mozilla \
				ca-certificates-utils \
				base \
				bash-completion \
				parted \
				rng-tools \
				e2fsprogs \
				dropbear \
				sudo \
				git \
				unbound


# build with the whole pi by default
RUN sed -i -e "s/^#MAKEFLAGS=.*/MAKEFLAGS=-j5/g" /etc/makepkg.conf


# INSTALL HNSD
USER builduser
RUN cd ~/ && \
		git clone https://github.com/faddat/hnsd-git && \
		cd hnsd-git && \
		makepkg -si --noconfirm --rmdeps --clean
USER root


# Use the Pi's Hardware rng.  You may wish to modify depending on your needs and desires: https://wiki.archlinux.org/index.php/Random_number_generation#Alternatives
RUN echo 'RNGD_OPTS="-o /dev/random -r /dev/hwrng"' > /etc/conf.d/rngd && \
		systemctl disable haveged && \
		systemctl enable rngd

# Set root password to root and make sure the user changes it at next login
RUN echo "root:root" | chpasswd


# =================================================================
# CLEANUP: Make the OS new and shiny.
# =================================================================

# Remove build tools
# RUN pacman -R --noconfirm base-devel
# Leave base-devel for now so we can ship a build.  Later figure out how to cleanly remove it.


# First Boot services
COPY ./contrib/firstboot.sh /usr/local/bin/firstboot.sh
COPY ./contrib/firstboot.service /etc/systemd/system/firstboot.service
COPY ./contrib/resizerootfs /usr/sbin/resizerootfs
COPY ./contrib/resizerootfs.service /etc/systemd/system
# Copy DNS configuration so that stub resolver goes to hsd and falls back to GOOD(tm) public DNS
COPY contrib/dns /etc/systemd/resolved.conf
# HNSD Service: In testing hnsd has been unreliable
COPY contrib/hnsd.service /etc/systemd/system/hnsd.service
# Greet Users Warmly
COPY contrib/motd /etc/

# Enable services
RUN systemctl enable firstboot && \
	systemctl enable resizerootfs && \
	systemctl enable systemd-resolved && \
	chmod +x /usr/local/bin/firstboot.sh && \
	chmod +x /usr/sbin/resizerootfs && \
	systemctl enable systemd-resolved && \
	systemctl enable hnsd && \
	chmod +x /usr/bin/hnsd && \
	# symlink systemd-resolved stub resolver to /etc/resolv/conf
	ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf && \
	systemctl enable dropbear

# Remove cruft and let pacman check for free disk space
RUN rm -rf \
		/etc/*- \
		/var/lib/systemd/* \
		/var/lib/private/* \
		/var/log/* \
		/var/tmp/* \
		/tmp/* \
		/root/.bash_history \
		/root/.cache \
		/home/*/.bash_history \
		/home/*/.cache \
		`LC_ALL=C pacman -Qo /var/cache/* 2>&1 | grep 'error: No package owns' | awk '{print $5}'` && \
		sed -i -e "s/^#!!!CheckSpace/CheckSpace/g" /etc/pacman.conf








