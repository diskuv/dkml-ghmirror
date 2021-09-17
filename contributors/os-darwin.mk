install-gitlab-cli:
	brew ls --versions glab || brew install glab

install-powershell: # for some reason ls --versions does not work
	brew ls powershell || brew install --cask powershell

install-shellcheck:
	brew ls --versions shellcheck || brew install shellcheck
