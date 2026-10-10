#!/usr/bin/env bash
# scripts/fetch-patches.sh
# Download automatizado da série oficial de patches do ZRAM de lore.kernel.org
# Gera patches em patches/upstream/ e metadados em references/provenance.json

set -euo pipefail

DEST_DIR="patches/upstream"
mkdir -p "$DEST_DIR"
mkdir -p "references"

BASE_MSGID="20261005122036.718976"
SENDER="senozhatsky@chromium.org"

echo "=== INICIANDO DOWNLOAD DOS PATCHES (LORE.KERNEL.ORG) ==="

declare -A PATCH_NAMES=(
    [1]="00-10-cover-letter.patch"
    [2]="01-10-prefix-backends-printk.patch"
    [3]="02-10-remove-debugfs-entry-on-init-failure.patch"
    [4]="03-10-zstd-do-not-allocate-empty-cd-dictionaries.patch"
    [5]="04-10-lz4hc-pre-initialize-dictionary-stream.patch"
    [6]="05-10-lz4-use-lz4-decompress-safe-usingdict.patch"
    [7]="06-10-lz4hc-use-lz4-decompress-safe-usingdict.patch"
    [8]="07-10-zstd-do-not-use-kvzalloc.patch"
    [9]="08-10-reset-writeback-on-reset.patch"
    [10]="09-10-split-zcomp-into-separate-rw-streams.patch"
    [11]="10-10-singleton-compression-context-recompression.patch"
)

# Iniciar array JSON
cat << 'EOF' > references/provenance.json
{
  "series_name": "zram: redesign zcomp and rework backends",
  "author": "Sergey Senozhatsky <senozhatsky@chromium.org>",
  "collaborator": "Barry Song <v-songbaohua@oppo.com>",
  "submission_date": "2026-10-05T12:20:36Z",
  "source_archive": "https://lore.kernel.org/all/",
  "retrieval_timestamp": "REPLACE_TIMESTAMP",
  "patches": [
EOF

sed -i "s|REPLACE_TIMESTAMP|$(date -Iseconds)|g" references/provenance.json

COUNT=0
TOTAL=11

for i in $(seq 1 11); do
    MSGID="${BASE_MSGID}-${i}-${SENDER}"
    URL="https://lore.kernel.org/all/${MSGID}/raw"
    FILENAME="${PATCH_NAMES[$i]}"
    OUTPATH="${DEST_DIR}/${FILENAME}"

    echo "Baixando [$i/$TOTAL]: $FILENAME ..."
    if curl -sSL -f --retry 3 --connect-timeout 10 "$URL" -o "$OUTPATH"; then
        SHA256=$(sha256sum "$OUTPATH" | awk '{print $1}')
        SUBJECT=$(grep "^Subject: " "$OUTPATH" | head -n 1 | sed 's/^Subject: //')
        BYTES=$(wc -c < "$OUTPATH")

        # Escrever entrada no JSON
        if [ "$COUNT" -gt 0 ]; then
            echo "    ," >> references/provenance.json
        fi

        cat << ENTRY >> references/provenance.json
    {
      "index": $COUNT,
      "filename": "$FILENAME",
      "message_id": "$MSGID",
      "url": "$URL",
      "subject": "$SUBJECT",
      "sha256": "$SHA256",
      "size_bytes": $BYTES
    }
ENTRY
        COUNT=$((COUNT + 1))
    else
        echo "ERRO ao baixar: $URL" >&2
        exit 1
    fi
done

cat << 'EOF' >> references/provenance.json
  ]
}
EOF

echo ""
echo "=== DOWNLOAD E AUDITORIA CONCLUÍDOS ==="
echo "Total de arquivos obtidos: $COUNT"
echo "Metadados gerados em: references/provenance.json"
