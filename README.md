# Usage
## Env vars
* `LISTEN_PORT`: Port to listen on, default `25565`
* `RCON_PORT`: Port for RCON to listen on
* `JAR_BUCKET`: Bucket containing your minecraft server jars.
* `JAR_FILE`: Name of the jar file you wish to run. Will search the jar bucket for this path exactly
* `WORLD_BUCKET`: Bucket containing your server worlds. Should have a dir in root called 'worlds'
* `WORLD`: Name of your world. Will search `WORLD_BUCKET/worlds` for this dir, or create it if it's missing
* `MAX_MEM`: Specify a hard memory limit for the JVM, in Kilobytes. If not set, use 80% of the instance's memory
* `RCON_PASSWORD`: A password to set on the RCON port. Automatically configured if left empty.
* `SERVER_USER`: Run as this user

The only required valies are `JAR_BUCKET`, `JAR_FILE`, and `WORLD_BUCKET`. If you omit `WORLD` it will default to `world`

## IAM
If using this outside of AWS, you will also need to specify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. While on AWS, you should attach a policy to your task role which allows S3 access.

```json
{
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "your:bucket:arn:here/*"
      ]
    },
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "your:bucket:arn:here"
      ]
    }
  ],
  "Version": "2012-10-17"
}
```
