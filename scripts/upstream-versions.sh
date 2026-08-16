#!/usr/bin/env bash
# Central, reviewed upstream pins for OpenCode Power Kit.
# Environment variables may override pins for controlled compatibility testing.

: "${OPK_BMAD_VERSION:=6.11.0}"
: "${OPK_GSD_VERSION:=1.8.0}"
: "${OPK_SUPERPOWERS_VERSION:=6.3.0}"
: "${OPK_MARKITDOWN_VERSION:=0.1.6}"
: "${OPK_TASTE_SOURCE:=https://github.com/Leonxlnx/taste-skill}"
: "${OPK_SUPERMEMORY_PACKAGE:=supermemory}"

export OPK_BMAD_VERSION OPK_GSD_VERSION OPK_SUPERPOWERS_VERSION
export OPK_MARKITDOWN_VERSION OPK_TASTE_SOURCE OPK_SUPERMEMORY_PACKAGE
