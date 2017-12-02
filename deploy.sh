git config user.name "anjia0532"
git config user.email "anjia0532@gmail.com"

git clone "https://${GH_TOKEN}@github.com/anjia0532/gcr.io_mirror.git"

imgs=$(curl -ks 'https://console.cloud.google.com/m/gcr/entities/list'  -H 'cookie: SID=WgX93aiB6sVpD_FPLDBsPHvLnYdhtMXYt9bHsf_TmrmIvLkrnc11D84pIcS-3WB9fYIHKw.; HSID=A--M5SxveLfh2e7Jl; SSID=AqvfThGwBO94ONF2d; OSID=ZAX93cIEBWYq35v3hq6J5U3MNU3voHihnEqmrmIirWBfHluQ3Gjbb4E24vDuPoSVKpC2tg.'  -H 'content-type: application/json;charset=UTF-8'   --data-binary '["google-containers"]' | grep -P '"' | sed 's/"gcr.ListEntities"//'|cut -d '"' -f2 |sort|uniq)

echo -e "Google Container Registry Mirror [last sync $(date +'%Y-%m-%d %H:%M')]\n-------\n\n[![Sync Status](https://travis-ci.org/anjia0532/gcr.io_mirror.svg?branch=sync)](https://travis-ci.org/anjia0532/gcr.io_mirror)\n\nTotal of $(echo ${imgs[@]} | grep -o ' ' | wc -l)'s gcr.io images\n-------\n\nUseage\n-------\n\n\`\`\`bash\ndocker pull gcr.io/google-containers/federation-controller-manager-arm64:v1.3.1-beta.1 \n# eq \ndocker pull anjia0532/federation-controller-manager-arm64:v1.3.1-beta.1\n\`\`\`\n\nImages\n-------\n\n" > gcr.io_mirror/README.md

for img in ${imgs[@]}  ; do
    gcr_content=$(curl -ks -X GET https://gcr.io/v2/google_containers/${img}/tags/list)
        
    if [ ! -d gcr.io_mirror/google_containers/${img} ] ; then
        mkdir -p gcr.io_mirror/google_containers/${img}
    fi
    
    echo -e "[gcr.io/google-containers/${img}](https://hub.docker.com/r/anjia0532/${img}/tags/) \n\n----" > gcr.io_mirror/google_containers/${img}/README.md
    
    echo ${gcr_content} | jq -r '.manifest[]|{k: .tag[0],v: .timeUploadedMs} | "touch -amd \"$(date -d @" + .v[0:10] +")\" gcr.io_mirror\/google_containers\/${img}\/"  +.k' | while read i; do
        eval $i
    done

    new_tags=$(find ./gcr.io_mirror/google_containers/${img} -path "*.md" -prune -o -mtime -1 -type f -exec basename {} \;)
    
    for tag in ${new_tags[@]};do
        docker pull gcr.io/google-containers/${img}:${tag}
        
        docker tag gcr.io/google-containers/${img}:${tag} ${user_name}/${img}:${tag}
        
        docker push ${user_name}/${img}:${tag}
        
        echo -e "**[gcr.io/google_containers/${img}:${tag} updated](https://hub.docker.com/r/anjia0532/${img}/tags/)**\n" >> gcr.io_mirror/google_containers/${img}/README.md
    done

    token=$(curl -ks https://auth.docker.io/token\?service\=registry.docker.io\&scope\=repository:${user_name}/${img}:pull | jq -r '.token')
    
    
    gcr_tags=$(echo ${gcr_content} | jq -r '.tags[]'|sort -r)
    
    hub_tags=$(curl -ks -H "authorization: Bearer ${token}"  https://registry.hub.docker.com/v2/${user_name}/${img}/tags/list | jq -r '.tags[]'|sort -r)
    
    for tag in ${gcr_tags}
    do
        
        if [ ! -z "${hub_tags[@]}" ] && (echo "${hub_tags[@]}" | grep -w "${tag}" &>/dev/null); then 
             echo google_containers/${img}:${tag} exits
        else
            docker pull gcr.io/google-containers/${img}:${tag}
            docker tag gcr.io/google-containers/${img}:${tag} ${user_name}/${img}:${tag}
            docker push ${user_name}/${img}:${tag}
        fi
        echo -e "[gcr.io/google_containers/${img}:${tag} √](https://hub.docker.com/r/anjia0532/${img}/tags/)\n" >> gcr.io_mirror/google_containers/${img}/README.md
        docker system prune -f -a
    done
    
    echo -e "[gcr.io/google_containers/${img} √](https://hub.docker.com/r/anjia0532/${img}/tags/)\n" >> gcr.io_mirror/README.md
done
cd gcr.io_mirror
git add .
git commit -m "sync gcr.io's images"
git push --quiet "https://${GH_TOKEN}@github.com/anjia0532/gcr.io_mirror.git" master:master

exit 0
