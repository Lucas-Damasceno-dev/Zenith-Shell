# Maintainer: Lucas Damasceno <https://github.com/Lucas-Damasceno-dev>
pkgname=zenith-shell-git
pkgver=1.0.0.r0
pkgrel=1
pkgdesc="Next-Gen Desktop Shell & Rice powered by Quickshell and Hyprland"
arch=('any')
url="https://github.com/Lucas-Damasceno-dev/Zenith-Shell"
license=('MIT')
depends=(
    'hyprland'
    'quickshell-git'
    'matugen-bin'
    'qt6-declarative'
    'qt6-5compat'
    'qt6-multimedia'
    'qt6-svg'
    'pipewire'
    'wireplumber'
    'playerctl'
    'socat'
    'jq'
    'grim'
    'slurp'
    'wl-clipboard'
    'cliphist'
    'brightnessctl'
    'libnotify'
    'imagemagick'
    'tesseract'
    'fd'
    'ripgrep'
    'papirus-icon-theme'
    'python'
    'python-requests'
)
optdepends=(
    'kitty: default terminal emulator'
    'brave-bin: default web browser'
    'thunar: default file manager'
    'awww: high-performance wallpaper daemon'
)
provides=('zenith-shell')
conflicts=('zenith-shell')
source=("git+${url}.git")
sha256sums=('SKIP')

pkgver() {
    cd "${srcdir}/Zenith-Shell"
    printf "1.0.0.r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
    cd "${srcdir}/Zenith-Shell"
    install -d "${pkgdir}/usr/share/zenith-shell"
    cp -r config systemd install.sh "${pkgdir}/usr/share/zenith-shell/"
    install -Dm755 install.sh "${pkgdir}/usr/bin/zenith-shell-installer"
}
