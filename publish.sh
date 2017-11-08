#!/bin/bash
#
# Copyright 2017 Garrett D'Amore <garrett@damore.org>
# Copyright 2017 Capitar IT Group BV <info@capitar.com>
# This software is supplied under the terms of the MIT License, a
# copy of which should be located in the distribution where this
# file was obtained (LICENSE.txt).  A copy of the license may also be
# found online at https://opensource.org/licenses/MIT.
#
# 
# This program attempts to publish updated documentation to nanomsg
# gh-pages branch, in the rfcs directory.
# 
# This script requires asciidoctor, pygments, git, asciidoctor-diagram,
# ditaa, packetdiag (from nwdiag) and a UNIX shell.
# 

tmpdir=$(mktemp -d)
srcdir=$(dirname $0)
dstdir=${tmpdir}/pages
dstrfcs=${dstdir}/rfcs
cd ${srcdir}
name=rfcs

giturl="${GITURL:-git@github.com:nanomsg/nanomsg}"

cleanup() {
	echo "DELETING ${tmpdir}"
	rm -rf ${tmpdir}
}

mkdir -p ${tmpdir}

trap cleanup 0

echo git clone ${giturl} ${dstdir} || exit 1
git clone ${giturl} ${dstdir} || exit 1

(cd ${dstdir}; git checkout gh-pages)

[ -d ${dstrfcs} ] || mkdir -p ${dstrfcs}

dirty=
for input in $(find . -name '*.adoc'); do
	adoc=${input#./}
	html=${adoc%.adoc}.html
	output=${dstrfcs}/${html}

	status=$(git status -s $input )
	when=$(git log -n1 --format='%ad' '--date=format-local:%s' $input )
	cat <<EOF > ${output}
---
layout: default
---
EOF

	if [ -n "$when" ]
	then
		epoch="SOURCE_DATE_EPOCH=${when}"
	else
		epoch=
		dirty=yes
	fi
	if [ -n "$status" ]
	then
		echo "File $adoc is not checked in!"
		dirty=yes
	fi


	env ${epoch} asciidoctor \
		-askip-front-matter \
		-bhtml5 \
		-r asciidoctor-diagram \
		-a imagesoutdir=${dstrfcs} \
		-D ${dstrfcs} \
		${adoc} -o - >> ${output}
	chmod 0644 ${output}

	if [ $? -ne 0 ]
	then
		echo "Failed to process $adoc !"
		fails=yes
	fi
done

if [ -n "$dirty" ]
then
	echo "Repository has uncommited documentation.  Aborting."
	exit 1
fi

if [ -n "$fails" ]
then
	echo "Failures formatting documentation. Aborting."
	exit 1
fi

(cd ${dstrfcs}; pwd; echo git add *.html *.png; git add *.html *.png; git commit -m "rfc updates"; git push origin gh-pages)
