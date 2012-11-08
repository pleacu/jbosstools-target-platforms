#!/bin/bash
# Hudson creates a repo in ${repoDir}; copy it into other places for access by downstream jobs and users

# defaults for JBoss Tools
# don't forget to increment these files when moving up a version:
# build.xml, *.target*, publish.sh, target2p2mirror.xml; also jbds/trunk/releng/org.jboss.ide.eclipse.releng/requirements/jbds-target-platform/build.properties;
# also all devstudio-6.0_*.updatesite jobs (4) need to be pointed at the new Target Platform URL
targetZipFile=e421-wtp341.target
repoDir=/home/hudson/static_build_env/jbds/tools/sources/REPO_4.0.juno.SR1a
destinationPath=/home/hudson/static_build_env/jbds/target-platform_4.0.juno.SR1a
DESTINATION=tools@filemgmt.jboss.org:/downloads_htdocs/tools/updates/target-platform_4.0.juno.SR1a
include="*"
exclude="--exclude '.blobstore'" # exclude the .blobstore

while [ "$#" -gt 0 ]; do
	case $1 in
		'-targetFile') targetZipFile="$2"; shift 2;; # old flag name (collision with build.xml's ${targetFile}, which points to a .target file)
		'-targetZipFile') targetZipFile="$2"; shift 2;;
		'-repoPath') repoDir="$2"; shift 2;; # old flag name (refactored to match build.xml's ${repoDir})
		'-repoDir') repoDir="$2"; shift 2;;
		'-destinationPath') destinationPath="$2"; shift 2;;
		'-DESTINATION') DESTINATION="$2"; shift 2;;
		'-include') include="$2"; shift 2;;
		'-exclude') exclude="$2"; shift 2;;

		'-jbosstools-JunoSR1a')
			# defaults for JBT (trunk)
			targetZipFile=e421-wtp341.target
			repoDir=/home/hudson/static_build_env/jbds/tools/sources/REPO_4.0.juno.SR1a
			destinationPath=/home/hudson/static_build_env/jbds/target-platform_4.0.juno.SR1a
			DESTINATION=tools@filemgmt.jboss.org:/downloads_htdocs/tools/updates/juno/SR1a
			include="*"
			exclude="--exclude '.blobstore'" # exclude the .blobstore
			shift 1;;

		'-jbdevstudio-JunoSR1a')
			# defaults for JBDS (trunk)
			targetZipFile=jbds600-e421-wtp341.target
			repoDir=/home/hudson/static_build_env/jbds/tools/sources/JBDS-REPO_4.0.juno.SR1a
			destinationPath=/home/hudson/static_build_env/jbds/jbds-target-platform_4.0.juno.SR1a
			DESTINATION=/qa/services/http/binaries/RHDS/updates/jbds-target-platform_4.0.juno.SR1a
			include="*"
			exclude="--exclude '.blobstore'" # exclude the .blobstore
			shift 1;;

		'-jbosstools-JunoSR0c')
			# defaults for JBT (trunk)
			targetZipFile=e420-wtp340.target
			repoDir=/home/hudson/static_build_env/jbds/tools/sources/REPO_4.0.juno.SR0c
			destinationPath=/home/hudson/static_build_env/jbds/target-platform_4.0.juno.SR0c
			DESTINATION=tools@filemgmt.jboss.org:/downloads_htdocs/tools/updates/juno/SR0c
			include="*"
			exclude="--exclude '.blobstore'" # exclude the .blobstore
			shift 1;;

		'-jbdevstudio-JunoSR0c')
			# defaults for JBDS (trunk)
			targetZipFile=jbds600-e420-wtp340.target
			repoDir=/home/hudson/static_build_env/jbds/tools/sources/JBDS-REPO_4.0.juno.SR0c
			destinationPath=/home/hudson/static_build_env/jbds/jbds-target-platform_4.0.juno.SR0c
			DESTINATION=/qa/services/http/binaries/RHDS/updates/jbds-target-platform_4.0.juno.SR0c
			include="*"
			exclude="--exclude '.blobstore'" # exclude the .blobstore
			shift 1;;

		*)
			echo "Unknown parameter " $1
			exit 1;;
	esac
done

if [[ -d ${repoDir} ]]; then
	cd ${repoDir}

	if [[ ! -d ${destinationPath}/${targetZipFile} ]]; then
		mkdir -p ${destinationPath}/${targetZipFile}
	fi
	du -sh ${repoDir} ${destinationPath}/${targetZipFile}

	# copy/update into central place for reuse by local downstream build jobs
	date; rsync -arzqc --protocol=28 --delete-after --delete-excluded --rsh=ssh ${exclude} ${include} ${destinationPath}/${targetZipFile}/

	du -sh ${repoDir} ${destinationPath}/${targetZipFile}

	# upload to http://download.jboss.org/jbossotools/updates/target-platform_3.3.indigo/REPO/ for public use
	if [[ ${DESTINATION/:/} == ${DESTINATION} ]]; then # local path, no user@server:/path
		mkdir -p ${DESTINATION}/
	else
		DESTPARENT=${DESTINATION%/*}; NEWFOLDER=${DESTINATION##*/}
		if [[ $(echo "ls" | sftp ${DESTPARENT} 2>&1 | grep ${NEWFOLDER}) == "" ]]; then
			# DESTHOST=${DESTINATION%:*}; DESTFOLD=${DESTINATION#*:}; echo "mkdir ${DESTFOLD}" | sftp ${DESTHOST}; # alternate approach
			echo "mkdir ${NEWFOLDER}" | sftp ${DESTPARENT}
		fi
	fi
	# if the following line fails, make sure that ${DESTINATION} is already created on target server
	date; rsync -arzqc --protocol=28 --delete-after --delete-excluded --rsh=ssh ${exclude} ${include} ${DESTINATION}/REPO/

	targetDir=/tmp/${targetZipFile}
	# create zip, then upload to http://download.jboss.org/jbossotools/updates/target-platform_3.3.indigo/${targetZipFile}.zip for public use
	targetZip=${targetDir}/${targetZipFile}.zip
	zip -q -r9 ${targetZip} ${include}
	du -sh ${targetZip}
	# generate MD5 sum for zip (file contains only the hash, not the hash + filename)
	for m in $(md5sum ${targetZip}); do if [[ $m != ${targetZip} ]]; then echo $m > ${targetZip}.MD5; fi; done
	# generate compositeContent.xml and compositeArtifacts.xml to make this URL a link to /REPO with p2
	timestamp=$(date +%s0000)
	echo "<?compositeMetadataRepository version='1.0.0'?>
<repository name='JBoss Tools Target Platform Site' type='org.eclipse.equinox.internal.p2.metadata.repository.CompositeMetadataRepository' version='1.0.0'>
  <properties size='2'>
    <property name='p2.compressed' value='true'/>
    <property name='p2.timestamp' value=\"${timestamp}\"/>
  </properties>
  <children size='1'>
    <child location='REPO/'/>
  </children>
</repository>" > ${targetDir}/compositeContent.xml
	echo "<?compositeArtifactRepository version='1.0.0'?>
<repository name='JBoss Tools Target Platform Site' type='org.eclipse.equinox.internal.p2.artifact.repository.CompositeArtifactRepository' version='1.0.0'>
  <properties size='2'>
    <property name='p2.compressed' value='true'/>
    <property name='p2.timestamp' value=\"${timestamp}\"/>
  </properties>
  <children size='1'>
    <child location='REPO/'/>
  </children>
</repository>" > ${targetDir}/compositeContent.xml

	date; rsync -arzq --protocol=28 --rsh=ssh ${targetDir}/* ${DESTINATION}/
	rm -f ${targetDir}
else
	echo "repoDir ${repoDir} not found or not a directory! Must exit!"
	exit 1;
fi
