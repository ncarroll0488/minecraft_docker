# Usage
## Env vars
* `LISTEN_PORT`: Port to listen on, default `25565`
* `RCON_PORT`: Port for RCON to listen on
* `JAR_BUCKET`: Bucket containing your minecraft server jars. Should have a dir in root called 'jars'
* `JAR_FILE`: Name of the jar file you wish to run
* `WORLD_BUCKET`: Bucket containing your server worlds. Should have a dir in root called 'worlds'
* `WORLD`: Name of your world. Will search `WORLD_BUCKET/worlds` for this dir, or create it if it's missing
* `MAX_MEM`: Specify a hard memory limit for the JVM, in Kilobytes. If not set, use 80% of the instance's memory
* `RCON_PASSWORD`: A password to set on the RCON port. Automatically configured if left empty.
* `SERVER_USER`: Run as this user
