# DkML Packaging Documentation

## Table of Contents

- [DkML Packaging Documentation](#dkml-packaging-documentation)
  - [Table of Contents](#table-of-contents)
  - [Developing](#developing)
    - [Requirements: Debian](#requirements-debian)
      - [Debian: conda](#debian-conda)
    - [Requirements: macOS](#requirements-macos)
      - [macOS: conda](#macos-conda)
    - [Requirements: Windows](#requirements-windows)
      - [Win32: conda](#win32-conda)
    - [Post-Install: direnv](#post-install-direnv)
    - [Post-Install: Visual Studio Code](#post-install-visual-studio-code)

## Developing

To build the documenation you will need to:

1. Check out the source code locally on your computer
2. Install the system requirements for your operating system:

   | System Requirements              |
   | -------------------------------- |
   | [Debian](#requirements-debian)   |
   | [macOS](#requirements-macos)     |
   | [Windows](#requirements-windows) |

Then you can use:

| Command                                                             | What                         |
| ------------------------------------------------------------------- | ---------------------------- |
| `cmake -D CONDA_ENVIRONMENT=DkMLPackaging`                          | Run a CMake command          |
| `conda run -n DkMLPackaging bump2version minor --dry-run`           | Dry run a minor version bump |
| `--config-file .bumpversion.prerelease.cfg --verbose --allow-dirty` |                              |

### Requirements: Debian

| Debian Packages | Installing                         |
| --------------- | ---------------------------------- |
| bump2version    | See [Debian: conda](#debian-conda) |

#### Debian: conda

FIRST, install the Python package manager "miniconda" (skip this step if you have already installed miniconda or anaconda):

```console
$ if ! command -v conda; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-py310_23.3.1-0-Linux-x86_64.sh
    printf "aef279d6baea7f67940f16aad17ebe5f6aac97487c7c03466ff01f4819e5a651  Miniconda3-py310_23.3.1-0-Linux-x86_64.sh\n" | sha256sum -c
  fi
Miniconda3-py310_23.3.1-0-Linux-x86_64.sh: OK

# If the security checksum does not say OK, do not continue.

$ if ! command -v conda; then bash Miniconda3-py310_23.3.1-0-Linux-x86_64.sh; fi
Please, press ENTER to continue
>>>
...
Do you accept the license terms? [yes|no]
[no] >>> yes
...
Miniconda3 will now be installed into this location:
/home/YOURUSER/miniconda3

  - Press ENTER to confirm the location
  - Press CTRL-C to abort the installation
  - Or specify a different location below

[/home/YOURUSER/miniconda3] >>>
...
Do you wish the installer to initialize Miniconda3
by running conda init? [yes|no]
[no] >>> yes
...
==> For changes to take effect, close and re-open your current shell. <==
...
Thank you for installing Miniconda3!
```

SECOND, close and re-open your current shell.

THIRD, run the following:

```console
$ conda update -n base -c defaults conda
...
Proceed ([y]/n)? y
...
Executing transaction: done
$ if ! conda list -q -n DkMLPackaging &>/dev/null; then
    conda env create -f environment.yml
  else
    conda env update -f environment.yml
  fi
```

*The above command can be run repeatedly; you can use it for upgrading Python dependencies.*

### Requirements: macOS

| macOS Packages | Installing                       |
| -------------- | -------------------------------- |
| bump2version   | See [macOS: conda](#macos-conda) |

#### macOS: conda

FIRST, install the Python package manager "miniconda" (skip this step if you have already installed miniconda or anaconda):

```console
$ if ! command -v conda; then
    brew install miniconda
  fi

...
==> Linking Binary 'conda' to '/opt/homebrew/bin/conda'
🍺  miniconda was successfully installed!
```

SECOND (optional!) if you like conda in your PATH you can do:

```console
$ conda init "$(basename "${SHELL}")"

...
==> For changes to take effect, close and re-open your current shell. <==
```

THIRD, close and re-open your current shell (ex. Terminal)

FOURTH, run the following:

```console
$ conda update -n base -c defaults conda
$ if ! conda list -q -n DkMLPackaging &>/dev/null; then
    conda env create -f environment.yml
  else
    conda env update -f environment.yml
  fi
```

*The above command can be run repeatedly; you can use it for upgrading Python dependencies.*

### Requirements: Windows

| Windows Packages | Installing                       |
| ---------------- | -------------------------------- |
| bump2version     | See [Win32: conda](#win32-conda) |

#### Win32: conda

FIRST download and install from <https://docs.conda.io/en/latest/miniconda.html>

SECOND, in **PowerShell** do the following:

```powershell
PS> &conda update -n base -c defaults conda
PS> &conda list -q -n DkMLPackaging | Out-Null
    if ($LASTEXITCODE) {
      &conda env create -f environment.yml
    } else {
      &conda env update -f environment.yml
    }
```

### Post-Install: direnv

If you use direnv (Unix only), the `.envrc` below will help you avoid typing in
`conda run -n DkMLPackaging` before every command.

Write the following `.envrc` in the project directory (same directory as this README):

```shell
#!/bin/sh
conda activate -n DkMLPackaging
```

### Post-Install: Visual Studio Code

If you installed Conda as recommended, you will need to install the Python extension (`ms-python.python`).

You will also need to tell Visual Studio Code where Conda is.
For example, on macOS it is typically:

```sh
/opt/homebrew/Caskroom/miniconda/base/bin/conda
```

and on Linux it is typically:

```sh
/home/YOURUSER/miniconda3/bin/conda
```

In Visual Studio Code you should manually specify the path to the `conda`
executable to use for activation. To do so, open the Command Palette (⇧⌘P on macOS, Ctrl-Shift-P on Linux and Windows) and
run `Preferences: Open User Settings`. Then set `python.condaPath`, which is in
the Python extension section of User Settings, with the appropriate path.
