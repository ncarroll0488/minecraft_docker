# Building the container
This is very easy. The container is based off of amazonlinux and has very few dependencies. CD into this directoy and run `./build-container.sh`. By default this tags the image as `unmined:latest`, but you may specify your own tag like this: `./build-container.sh MYTAG:MYVERSION`

*Warning*: Because the software in question does not offer a source code distribution, the entire download and extract process is done within the build, as to minimize risk to the host system. Extracting and executing files found within the container image is not recommended. Furthermore, if running using S3 or in ECS, provide the absolute bare-minimum policies to whichever IAM entity executes. This is typically just read access to the map data bucket, and read/write to the web document bucket.

# Running
## Environment
Two optional environment variables can be specified
* `MAP_SRC_S3`: An s3 URI which has your world data inside. The path specified should contain a "world" subfolder
* `MAP_DST_S3`: An s3 URI which contains your generated web documents. This is intended for use in an S3 hosted site.

As said, both parameters are optional. If `MAP_SRC_S3` is missing, nothing is downloaded - and whatever contents are present in `/app/map_src` are used. This allows the use of locally-provided data stores mapped via a docker volume.

If `MAP_DST_S3` is missing, nothing is uploaded when rendering is completed. Render output is written to `/app/map_web` inside the container. Again, a docker volume can be mapped to this directory to retreive artifacts after the render finishes.

## S3 storage
### Running locally
Create a `local.env` containing your S3 destination, source, and optionally your AWS credentials. (Credentials can also be specified by exporting vars and using `--env`). See `example.local.env` for the syntax. Once you're ready, execute this command, adjusting the image tag as needed:

```
docker run --env-file 'local.env' 'unmined:latest'
```

### Running in ECS
This works similarly to running locally, except you will be setting only two env variables in the task:
* `MAP_SRC_S3`
* `MAP_DST_S3`
These are set exactly the same as they would be when running locally. Additionally, You need to configure an IAM policy which does the following:
* Allows list/read access on objects in your map data bucket
* Allows list/read/write/delete access on objects in your web docs bucket
* Allows setting ACLs on your web docs bucket
This policy must be attached to your *task* role. Be very careful not to confuse that with your *execution* role.

## Local storage
### Local execution
If you're not an AWS S3 user, that's fine. You can still render your maps. You'll simply be responsible for publishing the web documents once rendering has finished. Firstly, create and populate a directory somewhere on your local filesystem:
```
mkdir -p /awesome/map_save
somecommand --output-to /awesome/map_save    #Whatever this is - rsync, tar, etc...
```

Now, create a directory somewhere on your local filesystem for web docs:
```
mkdir -p /web/documents
```

Next, run the container with volume mappings:
```
docker run -v '/awesome/map_save:/app/map_src' -v '/web/documents:/app/map_web' 'unmined:latest'
```

Provided the render works correctly, your web docs will be saved to `/web/documents`.

### ECS execution
"Local storage" can be used in ECS. Instead of mapping a docker volume locally using -v, you can instead map an EFS volume in the exact same way. Refer to [AWS documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/tutorial-efs-volumes.html)

## Local Storage + S3
If local volumes (or AWS ECS container-attached volume) are in-use, S3 can still be used to source your data. In this configuration, the "local" volumes serve as an extra caching layer which can minimize the amount of network I/O occurring during a render. Its uses cases are niche, but it's an option for those who want it.
