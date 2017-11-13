curl -ks 'https://console.cloud.google.com/m/gcr/entities/list'  -H 'cookie: SID=WgX93aiB6sVpD_FPLDBsPHvLnYdhtMXYt9bHsf_TmrmIvLkrnc11D84pIcS-3WB9fYIHKw.; HSID=A--M5SxveLfh2e7Jl; SSID=AqvfThGwBO94ONF2d; OSID=ZAX93cIEBWYq35v3hq6J5U3MNU3voHihnEqmrmIirWBfHluQ3Gjbb4E24vDuPoSVKpC2tg.'  -H 'content-type: application/json;charset=UTF-8'   --data-binary '["google-containers",null,null,[]]'  > /tmp/gcr.io

imgs=$(cat /tmp/gcr.io | grep -P '"' | sed 's/"gcr.ListEntities"//'|cut -d '"' -f2)

for img in ${imgs[@]}  ; do
    tags=$(curl -ks -X GET https://gcr.io/v2/google_containers/${img}/tags/list | jq -r '.tags[]'|sort -r)
    token=$(curl -ks https://auth.docker.io/token\?service\=registry.docker.io\&scope\=repository:${user_name}/${img}:pull | jq -r '.token')    
    TAGS=$(curl -ks -H "authorization: Bearer ${token}"  https://registry.hub.docker.com/v2/${user_name}/${img}/tags/list | jq -r '.tags[]'|sort -r)
    
    for tag in $tags
    do
        if [ ! -z "${TAGS[@]}" ] && (echo "${TAGS[@]}" | grep -w "${tag}" &>/dev/null); then 
            echo google_containers/${img}:${tag} exits
        else
            echo docker pull gcr.io/google-containers/${img}:${tag}
            docker pull gcr.io/google-containers/${img}:${tag}
            echo docker tag gcr.io/google-containers/${img}:${tag} ${user_name}/${img}:${tag}
            docker tag gcr.io/google-containers/${img}:${tag} ${user_name}/${img}:${tag}
            docker push ${user_name}/${img}:${tag}
            docker system prune -f -a
        fi
    done
done