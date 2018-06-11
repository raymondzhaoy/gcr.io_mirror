#!/bin/bash
# clone master branch
SECONDS=0

source ./process-utils.sh
process_init 20

[[ ! -d "gcr.io_mirror" ]] && git clone "https://github.com/anjia0532/gcr.io_mirror.git"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

function init_namespace()
{
  n=$1
  echo -e "${yellow}init gcr.io/$n's image...${plain}"
  # get all of the gcr images
  imgs=$(curl -ks 'https://console.cloud.google.com/m/gcr/entities/list' \
           -H 'Cookie: SID=MAb93Ze4dOeIV0K_odb4v5CoOItPYs_hQ5eEOrkAFFxjFap0d7QKYWap6hm5nG_0TChUJA.; HSID=AuemJ8zItxaNhLh0P; SSID=AF-GYPOCQp54kYz45; OSID=NAb93duc83kt_ekynf27EVwn6meJ38YxPKqA7sUFn9Z3Wi0otl_0_0F3bsMOxswv-0NkHA.;' \
           -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.7 Safari/537.36' \
           -H 'Content-Type: application/json;charset=UTF-8' \
           -H 'Accept: application/json, text/plain, */*' \
           --data-binary '["'${n}'",null,null,[]]' |
           grep -P '"' |
           sed 's/"gcr.ListEntities"//' |
           cut -d '"' -f2 |
           sort |
           uniq)

  for img in ${imgs[@]}  ; do
   process_run "init_imgs $img"
   #init_imgs $img
  done
}

function init_imgs()
{
  img=$1
  echo -e "${yellow}init gcr.io/$n/${img}'s image...${plain}"
  # get all  tags for this image
  gcr_content=$(curl -ks -X GET https://gcr.io/v2/${n}/${img}/tags/list)
  dir=gcr.io_mirror/${n}/${img}/

  # if this image dir not exits
  [[ ! -d ${dir} ]] && mkdir -p ${dir};

  # create img tmp file,named by tag's name, set access's time,modify's time by this image manifest's timeUploadedMs
  echo ${gcr_content} | jq -r '.manifest|to_entries[]|select(.value.tag|length>0)|{k: .key,t: .value.tag[0],v: .value.timeUploadedMs} | "tf=${dir}"+.t+".tmp;echo "+.k+">${tf};touch -amd \"$(date \"+%F %T\" -d @" + .v[0:10] +")\" ${tf}"' | while read i; do
    eval $i
  done
}

function compare()
{
  find ./gcr.io_mirror/ -name "*.tmp" | while read t
  do
    dir=$(dirname $t)
    name=$(basename $t .tmp)
    if [ -f ${dir}/${name} ] && [ $(cat ${dir}/${name})x = $(cat $t)x ]; then
      rm -rf $t;
    else
      [[ -f ${dir}/${name} ]] && rm -rf ${dir}/${name}
    fi
  done
}

function pull_push_diff()
{
  n=$1
  img=$2
  all_of_imgs=$(find ./gcr.io_mirror -type f \( ! -iname "*.md" \) |wc -l)
  current_ns_imgs=$(find ./gcr.io_mirror/${n}/ -type f \( ! -iname "*.md" \) |wc -l)
  tmps=($(find ./gcr.io_mirror/${n}/${img}/ -type f \( -iname "*.tmp" \) -exec basename {} .tmp \; | uniq))
  
  echo -e "${red}wait for mirror${plain}/${yellow} gcr.io/${n}/* images${plain}/${green}all of images${plain}:${red}${#tmps[@]}${plain}/${yellow}${current_ns_imgs}${plain}/${green}${all_of_imgs}${plain}"
  
  for tag in ${tmps[@]} ; do
    lock=./gcr.io_mirror/${n}/${img}/${tag}.lck
    [[ -f $lock ]] && continue;
    echo "${tag}">$lock
    
    docker pull gcr.io/${n}/${img}:${tag}
    docker tag gcr.io/${n}/${img}:${tag} ${user_name}/${n}.${img}:${tag}
    docker push ${user_name}/${n}.${img}:${tag}
    
    mv ./gcr.io_mirror/${n}/${img}/${tag}.tmp ./gcr.io_mirror/${n}/${img}/${tag}
    
    git -C ./gcr.io_mirror add ${n}/${img}/${tag}
    git -C ./gcr.io_mirror commit -m "${n}/${img}/${tag}"
    echo gcr.io/${n}/${img}:${tag}>> CHANGES.md
    rm -rf $lock
  done
}

function mirror()
{
  num=$(find ./gcr.io_mirror/ -type f \( -iname "*.tmp" \) |wc -l)
  if [ $num -eq 0 ]; then
    ns=$(cat ./gcr_namespaces 2>/dev/null || echo google-containers)
    for n in ${ns[@]}  ; do
      process_run "init_namespace $n"
      #init_namespace $n
    done
    wait
  fi
  
  tmps=$(find ./gcr.io_mirror/ -type f \( -iname "*.tmp" \) -exec dirname {} \; | uniq | cut -d'/' -f3-4)
  for img in ${tmps[@]} ; do
    n=$(echo ${img}|cut -d'/' -f1)
    image=$(echo ${img}|cut -d'/' -f2)
    process_run "pull_push_diff $n $image"
    #pull_push_diff $n $image
  done
  
  wait
  
  images=($(find ./gcr.io_mirror/ -type f -name "*" -not \( -path "./gcr.io_mirror/.git/*" -o -path "*.md" -o -path "*/LICENSE" -o -path "*.md" -o -path "*.tmp" -o -path "*.lck" \)|uniq|sort))
  find ./gcr.io_mirror/ -type f -name "*.md" -exec rm -rf {} \;
  
  for img in ${images[@]} ; do
    n=$(echo ${img}|cut -d'/' -f3)
    image=$(echo ${img}|cut -d'/' -f4)
    tag=$(echo ${img}|cut -d'/' -f5)
    mkdir -p ./gcr.io_mirror/${n}/{image}
    if [ ! -f ./gcr.io_mirror/${n}/{image}/README.md ]; then
      echo -e "\n[gcr.io/${n}/{image}](https://hub.docker.com/r/{user_name}/${n}.${image}/tags/)\n-----\n\n" >> ./gcr.io_mirror/${n}/{image}/README.md
      echo -e "\n[gcr.io/${n}/{image}](https://hub.docker.com/r/{user_name}/${n}.${image}/tags/)\n-----\n\n" >> ./gcr.io_mirror/${n}/README.md
    fi
    
    echo -e "[gcr.io/${n}/{image}:${tag}](https://hub.docker.com/r/{user_name}/${n}.${image}/tags/)\n-----\n\n" >> ./gcr.io_mirror/${n}/{image}/README.md
  done
  commit
}

function commit()
{
  ns=($(cat ./gcr_namespaces 2>/dev/null || echo google-containers))
  readme=./gcr.io_mirror/README.md
  envsubst < README.tpl >"${readme}"
  
  echo -e "Mirror ${#ns[@]} namespaces image from gcr.io\n-----\n\n" >> "${readme}"
  for n in ${ns[@]} ; do
    echo echo -e "[gcr.io/${n}/*](./${n}/README.md)\n\n" >> "${readme}"
  done
  
  git -C ./gcr.io_mirror add .
  git -C ./gcr.io_mirror commit -m "sync gcr.io's images at $(date +'%Y-%m-%d %H:%M')"
  git -C ./gcr.io_mirror push --quiet "https://${GH_TOKEN}@github.com/${user_name}/gcr.io_mirror.git" master:master
}

mirror &

while true;
do
  duration=$SECONDS
  if [ $duration -ge 2400 ]; then
    commit
    curl 'https://api.travis-ci.org/repo/16177067/requests' -H 'Travis-API-Version: 3' -H 'Authorization: token ${travis_token}' --data-binary '{"request":{"branch":"sync","config":"autobuild","message":"autobuild"}}'
    exit 0
  else
    sleep 60
  fi
done
