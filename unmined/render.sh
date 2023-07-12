#!/bin/bash -e

# Trim trailing slashes of our paths
MAP_SRC_S3="$(sed 's:/*$::' <<< "${MAP_SRC_S3}")"
MAP_DST_S3="$(sed 's:/*$::' <<< "${MAP_DST_S3}")"

if [ -n "${DEV_MODE}" ] ; then
  ZOOMIN=3
  ZOOMOUT=0
  FORCE=1
fi
[ -n "${FORCE}" ] && FORCE="-f"
grep -qE "^[0-9]+$" <<< "${ZOOMIN}"  || ZOOMIN=1
grep -qE "^[0-9]+$" <<< "${ZOOMOUT}"  || ZOOMOUT=6

# Sync the map data files down, if a map directory is specified.
[ -n "${MAP_SRC_S3}" ] && grep -qE '^s3://' <<< "${MAP_SRC_S3}" && {
  aws s3 sync --delete --exact-timestamps "${MAP_SRC_S3}/" "map_src/"
}

# Sync the rendered map's metadata files down so rendering and uploading is faster
[ -n "${MAP_DST_S3}" ] && grep -qE '^s3://' <<< "${MAP_DST_S3}" && {
  aws s3 cp "${MAP_DST_S3}/map.tar" "map.tar" && { echo "no tar present"
    tar -zxvf map.tar
    rm -f map.tar
  }
}

# Render the map in daytime mode
unmined-cli/unmined-cli web render "${FORCE}" --imageformat=png --shadows=true --zoomin="${ZOOMIN}" --zoomout="${ZOOMOUT}" --background='#202020' --world="map_src/world" --output="map_web/overworld_day"

# Copy the daytime indexfile into place
cp 'map_web/overworld_day/unmined.index.html' 'map_web/overworld_day/index.html'

# Render the map in nighttime mode
unmined-cli/unmined-cli web render "${FORCE}" --imageformat=png --night=true --shadows=false --zoomin="${ZOOMIN}" --zoomout="${ZOOMOUT}" --background='#101010' --world="map_src/world" --output="map_web/overworld_night"

# Copy the nighttime indexfile into place
cp 'map_web/overworld_night/unmined.index.html' 'map_web/overworld_night/index.html'

# Copy the main indexfile into place
cp 'main.index.html' 'map_web/index.html'

[ -n "${MAP_DST_S3}" ] && grep -qE '^s3://' <<< "${MAP_DST_S3}" && {
  # Upload the map to S3 if requested. Make a tar for easy upload/download
  tar  -czvf 'map.tar' 'map_web/'
  aws s3 cp --acl 'private' 'map.tar' "${MAP_DST_S3}/map.tar"
  aws s3 sync --exact-timestamps --acl 'public-read' 'map_web/' "${MAP_DST_S3}/"
}
