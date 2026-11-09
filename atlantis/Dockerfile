# Atlantis with the three binaries its steps and pre-workflow hooks call:
# terraform (the image doesn't ship it), terramate and terramate-atlantis-config.
FROM ghcr.io/runatlantis/atlantis:v0.49.0

ARG TERRAFORM_VERSION=1.15.8
ARG TERRAMATE_VERSION=0.17.3
ARG TMAC_VERSION=1.3.0
ARG TARGETARCH

USER root

RUN set -eux; \
	arch="${TARGETARCH:-amd64}"; \
	case "$arch" in \
		amd64) tm_arch=x86_64 ;; \
		arm64) tm_arch=arm64 ;; \
		*) echo "unsupported arch: $arch" >&2; exit 1 ;; \
	esac; \
	tmp="$(mktemp -d)"; cd "$tmp"; \
	hc=https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}; \
	curl -fsSLO "$hc/terraform_${TERRAFORM_VERSION}_linux_${arch}.zip"; \
	curl -fsSLO "$hc/terraform_${TERRAFORM_VERSION}_SHA256SUMS"; \
	grep " terraform_${TERRAFORM_VERSION}_linux_${arch}.zip\$" \
		"terraform_${TERRAFORM_VERSION}_SHA256SUMS" | sha256sum -c -; \
	unzip -q "terraform_${TERRAFORM_VERSION}_linux_${arch}.zip" terraform -d /usr/local/bin; \
	tm=https://github.com/terramate-io/terramate/releases/download/v${TERRAMATE_VERSION}; \
	curl -fsSLO "$tm/terramate_${TERRAMATE_VERSION}_linux_${tm_arch}.tar.gz"; \
	curl -fsSL -o tm-checksums.txt "$tm/checksums.txt"; \
	grep " terramate_${TERRAMATE_VERSION}_linux_${tm_arch}.tar.gz\$" tm-checksums.txt | sha256sum -c -; \
	tar -xzf "terramate_${TERRAMATE_VERSION}_linux_${tm_arch}.tar.gz" -C /usr/local/bin terramate; \
	tmac=https://github.com/devops-roast/terramate-atlantis-config/releases/download/v${TMAC_VERSION}; \
	curl -fsSLO "$tmac/terramate-atlantis-config_${TMAC_VERSION}_linux_${arch}.tar.gz"; \
	curl -fsSL -o tmac-checksums.txt "$tmac/checksums.txt"; \
	grep " terramate-atlantis-config_${TMAC_VERSION}_linux_${arch}.tar.gz\$" tmac-checksums.txt | sha256sum -c -; \
	tar -xzf "terramate-atlantis-config_${TMAC_VERSION}_linux_${arch}.tar.gz" \
		-C /usr/local/bin terramate-atlantis-config; \
	cd /; rm -rf "$tmp"; \
	terraform version; terramate version; terramate-atlantis-config version

USER atlantis
