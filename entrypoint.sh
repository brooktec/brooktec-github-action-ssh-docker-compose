#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/workspace.tar.bz2
}
trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/workspace.tar.bz2 --exclude .git --exclude vendor .

log "Launching ssh agent."
eval `ssh-agent -s`

remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/$WORKSPACE\" ; log 'Unpacking workspace...' ; cd \"\$HOME/$WORKSPACE\" ; tar -xjv ; log 'Launching docker compose...' ; cd \"\$HOME/$WORKSPACE\" ; docker compose -f \"$DOCKER_COMPOSE_FILENAME\" pull ; docker compose -f \"$DOCKER_COMPOSE_FILENAME\" up -d --remove-orphans --build"

if $DOCKER_COMPOSE_DOWN ; then
  remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/$WORKSPACE\" ; log 'Unpacking workspace...' ; cd \"\$HOME/$WORKSPACE\" ; tar -xjv ; log 'Docker compose down...' ; docker compose -f \"$DOCKER_COMPOSE_FILENAME\" down ; log 'Docker compose pulling...' ; docker compose -f \"$DOCKER_COMPOSE_FILENAME\" pull ; log 'Docker compose up...' ; docker compose -f \"$DOCKER_COMPOSE_FILENAME\" up -d --remove-orphans --build"
fi

ssh-add <(echo "$SSH_PRIVATE_KEY")

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2
