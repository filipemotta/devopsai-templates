FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends bash ca-certificates jq \
 && rm -rf /var/lib/apt/lists/*
# Pinned binaries, downloaded and checksum-verified in the image build pipeline
COPY bin/terraform bin/ant /usr/local/bin/
# Providers come from a local mirror: the container never talks to the registry
#   terraform providers mirror -platform=linux_amd64 ./tf-mirror   (at build time)
COPY tf-mirror/ /opt/tf-mirror/
COPY terraformrc /etc/terraformrc
COPY drift-scan.sh summarize.jq /opt/drift/
ENV TF_CLI_CONFIG_FILE=/etc/terraformrc
RUN useradd -u 1000 -m drift \
 && mkdir -p /workspace /mnt/memory && chown drift /workspace /mnt/memory
USER drift
ENTRYPOINT ["ant", "beta:worker", "run", "--workdir", "/workspace"]

