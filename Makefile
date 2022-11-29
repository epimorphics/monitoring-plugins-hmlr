NAME?=monitoring-hmlr
VERSION?=SNAPSHOT
ROOT=${NAME}_${VERSION}
TGZ=${ROOT}_linux_amd64.tar.gz
SHA=${ROOT}_sha512-checksums.txt

all: clean assets

assets: sha

sha: ${SHA}
	
${TGZ}:
	@echo "Creating ${TGZ} ..."
	@tar zcf ${TGZ} bin

${SHA}: ${TGZ}
	@sha512sum ${TGZ} | tee ${SHA}

clean:
	@rm -f ${TGZ} ${SHA}
