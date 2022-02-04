#!/bin/bash
mkdir -p requirements
pip download -d requirements -r requirements.txt
unzip 'requirements/*.whl' -d requirements
rm requirements/*.whl
mkdir -p python
mv requirements/* python
zip -r lib.zip python
rm -r requirements
rm -r python