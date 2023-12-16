#!/bin/bash
rm dist/ -rf
npm install && \
rm -f *.gma outfitter_publish/*.gma && \
cp addon.json dist/ && \
LD_LIBRARY_PATH=ci/gluac/ ./ci/gluac/gmad_linux create -folder dist -out outfitter-$(date +'%Y-%m-%d').gma && \
mv *.gma outfitter_publish/ && \
sleep 5 && \
"$HOME/steamcmd.sh" +login metastruct +workshop_build_item "$PWD/outfitter_publish.vdf"

