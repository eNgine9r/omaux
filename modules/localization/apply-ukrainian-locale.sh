#!/usr/bin/env bash
set -euo pipefail

locale_root="$HOME/.local/lib/locale"
locale_name="uk_UA.UTF-8"
locale_dir="$locale_root/$locale_name"
mkdir -p "$locale_root" "$HOME/.config/environment.d"

if [[ ! -f "$locale_dir/LC_TIME" ]]; then
  localedef -i uk_UA -f UTF-8 "$locale_dir"
fi

cat >"$HOME/.config/environment.d/90-omarchy-ukrainian.conf" <<EOF
LANG=uk_UA.UTF-8
LANGUAGE=uk_UA:uk:en
LOCPATH=$locale_root
LC_NUMERIC=C.UTF-8
EOF

systemctl --user set-environment \
  LANG=uk_UA.UTF-8 \
  LANGUAGE=uk_UA:uk:en \
  LOCPATH="$locale_root" \
  LC_NUMERIC=C.UTF-8

echo "Ukrainian locale ready: $locale_dir"
