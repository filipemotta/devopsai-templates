FROM debian:12-slim
ARG ANT_VERSION=2.7.1
ARG KUBECTL_VERSION=1.36.0          # keep within one minor of the cluster
ARG TARGETARCH
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl jq unzip \
 && ARCH=$([ "$TARGETARCH" = "arm64" ] && echo arm64 || echo amd64) \
 && curl -fsSL "https://github.com/anthropics/anthropic-cli/releases/download/v${ANT_VERSION}/ant_${ANT_VERSION}_linux_${ARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin ant \
 && curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
 && chmod +x /usr/local/bin/kubectl \
 && AWSARCH=$([ "$ARCH" = "arm64" ] && echo aarch64 || echo x86_64) \
 && curl -fsSLo /tmp/awscli.zip "https://awscli.amazonaws.com/awscli-exe-linux-${AWSARCH}.zip" \
 && unzip -q /tmp/awscli.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscli.zip \
 && apt-get purge -y unzip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* \
 && useradd -u 10001 -M -d /tmp readiness
COPY readiness-scan.sh /opt/readiness/readiness-scan.sh
USER 10001
WORKDIR /workspace
ENTRYPOINT ["ant", "beta:worker", "poll", "--workdir", "/workspace"]
