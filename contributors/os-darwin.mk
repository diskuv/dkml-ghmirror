install-gitlab-cli:
	brew ls --versions glab || brew install glab

install-powershell: # for some reason ls --versions does not work
	brew ls powershell || brew install --cask powershell

install-shellcheck:
	brew ls --versions shellcheck || brew install shellcheck

install-gitlab-release-cli:
	if ! which release-cli >/dev/null 2>&1; then \
		set -x && \
		curl -L "https://gitlab.com/api/v4/projects/gitlab-org%2Frelease-cli/packages/generic/release-cli/latest/release-cli-darwin-amd64" -o /tmp/release-cli && \
		chmod +x /tmp/release-cli && \
		sudo mv /tmp/release-cli /usr/local/bin; \
	fi
