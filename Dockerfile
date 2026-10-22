FROM ubuntu:24.04

ARG RUNNER_VERSION=2.336.0
ARG RUNNER_SHA256=04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    docker.io \
    git \
    jq \
    libicu74 \
    libssl3 \
    runit \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner

WORKDIR /opt/actions-runner

RUN curl --fail --location --retry 3 \
    --output actions-runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && echo "${RUNNER_SHA256}  actions-runner.tar.gz" | sha256sum --check - \
    && tar --extract --gzip --file actions-runner.tar.gz \
    && rm actions-runner.tar.gz \
    && ./bin/installdependencies.sh \
    && chown -R runner:runner /opt/actions-runner

COPY --chmod=0755 entrypoint.sh /usr/local/bin/runner-entrypoint

ENTRYPOINT ["/usr/local/bin/runner-entrypoint"]
