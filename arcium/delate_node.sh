echo "--- Removing Arcium ---"

# Remove arcup binary
rm -f /root/.cargo/bin/arcup

# Remove any hidden Arcium folders (якщо були створені)
rm -rf ~/.arcium ~/.config/arcium ~/.cache/arcium ~/.local/share/arcium

# Remove Arcium Docker images
docker rmi arcium/arx-node:v0.4.0 2>/dev/null || true
docker rmi arcium/arx-node:latest 2>/dev/null || true

echo "✅ Arcium removed!"

rm -rf ~/.config/solana
echo "✅ Solana cleanup complete!"
