/^#/ {
	gsub(/^#./, "", $0) > "/tmp/yazi-http-preview.md"
}

