git config user.name "anjia0532"
git config user.email "anjia0532@gmail.com"

# clone master branch
git clone "https://github.com/anjia0532/gcr.io_mirror.git"

# init README.md
cat <<EOT >> gcr.io_mirror/README.md
Google Container Registry Mirror [last sync 2018-06-05 12:28 UTC]
-------

[![Sync Status](https://travis-ci.org/anjia0532/gcr.io_mirror.svg?branch=sync)](https://travis-ci.org/anjia0532/gcr.io_mirror)

Syntax
-------

\`\`\`bash
gcr.io/namespace/image_name:image_tag eq ${user_name}/namespace.image_name:image_tag
\`\`\`

Example
-------

\`\`\`bash
docker pull gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 
# eq 
docker pull ${user_name}/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1
\`\`\`

ReTag ${user_name} images to gcr.io 
-------

\`\`\`bash
# replace gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 to real image
# this will convert gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 
# to ${user_name}/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1 and pull 
eval \$(echo \$(cat <<EOF
gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
EOF
)| sed 's/gcr\.io/${user_name}/g;s/\//\./g;s/ /\n/g;s/${user_name}\./${user_name}\//g' | uniq | awk '{print "docker pull "\$1";"}')

# this code will retag all of ${user_name}'s image from local  e.g. ${user_name}/google-containers.federation-controller-manager-arm64:v1.3.1-beta.1 
# to gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1
eval \$(docker images | grep ${user_name} | awk '{print \$1":"\$2}' |awk -F'[/.:]' '{printf "docker tag %s/%s.%s:%s gcr.io/%s/%s:%s;\n",\$1,\$2,\$3,\$4,\$2,\$3,\$4}')
\`\`\`

[Changelog](./CHANGES.md)
-------

EOT

# create changelog md
if [ ! -s gcr.io_mirror/CHANGES.md ]; then
    echo -e "\n" > gcr.io_mirror/CHANGES.md
fi

# sync branch tmp changelog md
if [ ! -f CHANGES.md ]; then
    touch CHANGES.md
fi

ns=$(cat ./gcr_namespaces 2>/dev/null || echo google-containers)

for n in ${ns[@]}  ; do

    # get all of the gcr images
    imgs=$(curl -ks 'https://console.cloud.google.com/m/gcr/entities/list'  -H 'cookie: SID=WgX93aiB6sVpD_FPLDBsPHvLnYdhtMXYt9bHsf_TmrmIvLkrnc11D84pIcS-3WB9fYIHKw.; HSID=A--M5SxveLfh2e7Jl; SSID=AqvfThGwBO94ONF2d; OSID=ZAX93cIEBWYq35v3hq6J5U3MNU3voHihnEqmrmIirWBfHluQ3Gjbb4E24vDuPoSVKpC2tg.'  -H 'content-type: application/json;charset=UTF-8'   --data-binary '["'${n}'"]' | grep -P '"' | sed 's/"gcr.ListEntities"//'|cut -d '"' -f2 |sort|uniq)

	echo -e "Total of $(echo ${imgs[@]} | grep -o ' ' | wc -l)'s gcr.io/${n}/* images\n\n-------\n\n" >> gcr.io_mirror/README.md
	
    # remove all of the imgs tmp file
    rm -rf "./gcr.io_mirror/${n}/*"

    for img in ${imgs[@]}  ; do
        # get all  tags for this image
        gcr_content=$(curl -ks -X GET https://gcr.io/v2/${n}/${img}/tags/list)
        
        # if this image dir not exits 
        if [ ! -d gcr.io_mirror/${n}/${img} ] ; then
            mkdir -p gcr.io_mirror/${n}/${img}
        fi
        
        # create image README.md
		
        echo -e "[gcr.io/${n}/${img}](https://hub.docker.com/r/anjia0532/${img}/tags/) \n\n----" >> gcr.io_mirror/${n}/README.md
        echo -e "[gcr.io/${n}/${img}](https://hub.docker.com/r/anjia0532/${img}/tags/) \n\n----" > gcr.io_mirror/${n}/${img}/README.md
        # create img tmp file,named by tag's name, set access's time,modify's time by this image manifest's timeUploadedMs
        echo ${gcr_content} | jq -r '.manifest[]|{k: .tag[0],v: .timeUploadedMs} | "touch -amd \"$(date -d @" + .v[0:10] +")\" gcr.io_mirror\/${n}\/${img}\/"  +.k' | while read i; do
            eval $i
        done
        
        # get all of the files by last modify time after yesterday,it was new image
        new_tags=$(find ./gcr.io_mirror/${n}/${img} -path "*.md" -prune -o -mtime -1 -type f -exec basename {} \;)
        
        for tag in ${new_tags[@]};do
            docker pull gcr.io/${n}/${img}:${tag}
            
            docker tag gcr.io/${n}/${img}:${tag} ${user_name}/${img}:${tag}
            
            docker push ${user_name}/${img}:${tag}
            
            # write this to changelogs
            echo -e "1. [gcr.io/${n}/${img}:${tag} updated](https://hub.docker.com/r/${user_name}/${n}.${img}/tags/) \n\n" >> CHANGES.md
            
            # image readme.md
            echo -e "**[gcr.io/${n}/${img}:${tag} updated](https://hub.docker.com/r/${user_name}/${n}.${img}/tags/)**\n" >> gcr.io_mirror/${n}/${img}/README.md
        done

        # docker hub pull's token
        token=$(curl -ks https://auth.docker.io/token\?service\=registry.docker.io\&scope\=repository:${user_name}/${img}:pull | jq -r '.token')
        
        # get this gcr image's tags
        gcr_tags=$(echo ${gcr_content} | jq -r '.tags[]'|sort -r)
        
        # get this docker hub image's tags
        hub_tags=$(curl -ks -H "authorization: Bearer ${token}"  https://registry.hub.docker.com/v2/${user_name}/${img}/tags/list | jq -r '.tags[]'|sort -r)
        
        for tag in ${gcr_tags}
        do
            # if both of the gcr and docker hub ,not do anythings
            if [ ! -z "${hub_tags[@]}" ] && (echo "${hub_tags[@]}" | grep -w "${tag}" &>/dev/null); then 
                 echo ${n}/${img}:${tag} exits
            else
                docker pull gcr.io/${n}/${img}:${tag}
                docker tag gcr.io/${n}/${img}:${tag} ${user_name}/${img}:${tag}
                docker push ${user_name}/${img}:${tag}
            fi
            # old img tag write to image's readme.md
            echo -e "[gcr.io/${n}/${img}:${tag} √](https://hub.docker.com/r/${user_name}/${n}.${img}/tags/)\n" >> gcr.io_mirror/${n}/${img}/README.md
            echo -e "[gcr.io/${n}/${img}:${tag} √](https://hub.docker.com/r/${user_name}/${n}.${img}/tags/)\n" >> gcr.io_mirror/${n}/README.md
            
            # cleanup the docker file
            docker system prune -f -a
        done
        
        echo -e "[gcr.io/${n}/${img} √](https://hub.docker.com/r/${user_name}/${n}.${img}/tags/)\n" >> gcr.io_mirror/README.md
    done
done
if [ -s CHANGES.md ]; then
    (echo -e "## $(date +%Y-%m-%d) \n" && cat CHANGES.md && cat gcr.io_mirror/CHANGES.md) > gcr.io_mirror/CHANGES1.md && mv gcr.io_mirror/CHANGES1.md gcr.io_mirror/CHANGES.md
fi

cd gcr.io_mirror
git add .
git commit -m "sync gcr.io's images at $(date +'%Y-%m-%d %H:%M')"
git push --quiet "https://${GH_TOKEN}@github.com/${user_name}/gcr.io_mirror.git" master:master

exit 0
