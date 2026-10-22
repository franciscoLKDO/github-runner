#!/usr/bin/env bash
set -euo pipefail

cd /opt/actions-runner

: "${RUNNER_REPOSITORY_URL:?Set RUNNER_REPOSITORY_URL in .env}"

if [[ -n "${TELEMETRY_CA_PATH:-}" && -f "${TELEMETRY_CA_PATH}" ]]; then
  install -m 0644 "${TELEMETRY_CA_PATH}" /usr/local/share/ca-certificates/cabane-telemetry.crt
  update-ca-certificates >/dev/null
fi

docker_gid="$(stat -c '%g' /var/run/docker.sock)"
if ! getent group "${docker_gid}" >/dev/null; then
  groupadd --gid "${docker_gid}" host-docker
fi
docker_group="$(getent group "${docker_gid}" | cut -d: -f1)"
usermod -aG "${docker_group}" runner

registration_token="${RUNNER_TOKEN:-}"
if [[ -z "${registration_token}" && -n "${GH_TOKEN:-}" ]]; then
  repository_path="${RUNNER_REPOSITORY_URL#https://github.com/}"
  repository_path="${repository_path%.git}"
  registration_token="$(
    curl --fail --silent --show-error --request POST \
      --header "Accept: application/vnd.github+json" \
      --header "Authorization: Bearer ${GH_TOKEN}" \
      --header "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/${repository_path}/actions/runners/registration-token" |
      jq --exit-status --raw-output '.token'
  )"
fi

if [[ -z "${registration_token}" ]]; then
  echo "Set RUNNER_TOKEN or GH_TOKEN in .env." >&2
  exit 1
fi

config_args=(
  --unattended
  --replace
  --url "${RUNNER_REPOSITORY_URL}"
  --token "${registration_token}"
  --name "${RUNNER_NAME:-cabane-release-poc}"
  --labels "${RUNNER_LABELS:-cabane-release}"
  --work _work
)

if [[ "${RUNNER_EPHEMERAL:-false}" == "true" ]]; then
  config_args+=(--ephemeral)
fi

runuser -u runner -- ./config.sh "${config_args[@]}"
exec runuser -u runner -- ./run.sh
