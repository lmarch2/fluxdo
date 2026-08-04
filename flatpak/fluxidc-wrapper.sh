#!/usr/bin/env bash

set -euo pipefail

export LD_LIBRARY_PATH="/app/idcflare/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# The app already runs inside Flatpak's sandbox. Letting WebKit spawn an
# additional bubblewrap sandbox for its WebProcess can crash WPE under Flatpak.
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1

cd /app/idcflare
exec /app/idcflare/idcflare "$@"
