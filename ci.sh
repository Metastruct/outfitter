#!/bin/bash
([ ! -d ci ] && mkdir ci && cd ci && wget https://github.com/Metastruct/gtravis/releases/download/travisbins/gluac.tar.xz && tar -xf gluac.tar.xz; rm -f gluac.tar.xz)

export LD_LIBRARY_PATH=`pwd`/ci/gluac${LD_LIBRARY_PATH:+:}${LD_LIBRARY_PATH:-}
export PATH=$PATH:`pwd`/ci/gluac

while true; do

	inotifywait -e modify,create,delete -r lua && \
	find lua/ -iname '*.lua' -print0 | xargs -0 -- gluac -p -- && \
	npm install

done

