install-github-cli:
	@PATH="$$PATH:/usr/bin:/bin"; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then \
		pacman --sync --needed --noconfirm mingw64/mingw-w64-x86_64-github-cli; \
	fi
	@PATH="/usr/bin:/bin:/mingw64/bin:$$PATH"; if ! which gh >/dev/null 2>&1; then \
		echo "FATAL: GitHub CLI was not installed, and the Makefile does not know how to install it." >&2; exit 1; \
	fi

install-gitlab-cli:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; \
	if ! which glab >/dev/null 2>&1; then \
		curl -L https://github.com/profclems/glab/releases/download/v1.20.0/glab_1.20.0_Windows_x86_64.zip -o /tmp/glab.zip && \
		rm -rf /tmp/glab && \
		unzip -d /tmp/glab /tmp/glab.zip && install -d /usr/local/bin && install /tmp/glab/bin/glab.exe /usr/local/bin/; \
	fi

install-gitlab-release-cli:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; \
	if ! which release-cli >/dev/null 2>&1; then \
		curl -L "https://gitlab.com/api/v4/projects/gitlab-org%2Frelease-cli/packages/generic/release-cli/latest/release-cli-windows-amd64.exe" -o /tmp/release-cli.exe && \
		mv /tmp/release-cli.exe /usr/local/bin; \
	fi

install-zip:
	@PATH="$$PATH:/usr/bin:/bin"; \
	if which pacman >/dev/null 2>&1 && which cygpath >/dev/null 2>&1; then \
		pacman --sync --needed --noconfirm zip; \
	fi
	@PATH="/usr/bin:/bin:/mingw64/bin:$$PATH"; if ! which zip >/dev/null 2>&1; then \
		echo "FATAL: 'zip' was not installed, and the Makefile does not know how to install it." >&2; exit 1; \
	fi

install-powershell:

/usr/local/bin/shellcheck.exe:
	@PATH="/usr/local/bin:/usr/bin:/bin:/mingw64/bin:$$PATH"; \
	if ! which shellcheck >/dev/null 2>&1; then \
		curl -L https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.zip -o /tmp/shellcheck-stable.zip; \
		rm -rf /tmp/shellcheck && \
		unzip -d /tmp/shellcheck /tmp/shellcheck-stable.zip && install -d /usr/local/bin && install /tmp/shellcheck/shellcheck.exe /usr/local/bin; \
	fi

install-shellcheck: /usr/local/bin/shellcheck.exe
