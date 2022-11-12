# Configuration file for the Sphinx documentation builder.
#
# This file only contains a selection of the most common options. For a full
# list see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Path setup --------------------------------------------------------------

# If extensions (or modules to document with autodoc) are in another directory,
# add these directories to sys.path here. If the directory is relative to the
# documentation root, use os.path.abspath to make it absolute, like shown here.
#
# import os
# import sys
# sys.path.insert(0, os.path.abspath('.'))

# import sphinx_rtd_theme
from pathlib import Path
import shutil
import subprocess

# -- Project information -----------------------------------------------------

project = 'Diskuv OCaml 1.0.2-prerel1'
copyright = '2021, Diskuv, Inc.'
author = 'Diskuv, Inc.'


# -- General configuration ---------------------------------------------------

# Add any Sphinx extension module names here, as strings. They can be
# extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
# ones.
extensions = [
    # "sphinx_rtd_theme",
    "sphinx.ext.graphviz"
]

# Add any paths that contain templates here, relative to this directory.
templates_path = ['_templates']

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store', '_opam', 'envs']


# -- Options for HTML output -------------------------------------------------

# The theme to use for HTML and HTML Help pages.  See the documentation for
# a list of builtin themes.
#
html_theme = 'sphinx_rtd_theme'
html_theme_path = ["themes/custom_sphinx_rtd_theme"]

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
html_static_path = ['_static']

html_theme_options = {
    'style_nav_header_background': '#3347A9'
}

# -- Optional for graphviz ---------------------------------------------------

graphviz_output_format = 'svg'

# Set graphviz_dot
graphviz_dot_candidates = ["/mingw64/bin/dot.exe"]
graphviz_dot_final = None
cygpath_exe = shutil.which("cygpath")
for _c in graphviz_dot_candidates:
    if cygpath_exe is not None:
        _c = subprocess.check_output([cygpath_exe, '-aw', _c], universal_newlines=True).strip()
    if Path(_c).exists():
        graphviz_dot_final = _c
        break
if graphviz_dot_final is None:
    graphviz_dot = "dot"
else:
    graphviz_dot = graphviz_dot_final
