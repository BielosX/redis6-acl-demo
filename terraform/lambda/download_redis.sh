#!/bin/bash
pip download redis --no-deps
pip download packaging --no-deps
mv redis-*.whl redis.zip
rm -r redis-*
mv packaging-*.whl packaging.zip
mkdir -p python
unzip redis.zip
unzip packaging.zip
rm -r packaging-*
mv packaging python
rm redis.zip
rm packaging.zip
mv redis python
zip -r redis.zip python
rm -r python