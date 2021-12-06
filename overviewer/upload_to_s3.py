import boto3
import os
import sys

def main () :
  prefix = sys.argv[1].rstrip('/')
  bucket = sys.argv[2]
  path_prefix = sys.argv[3]
  changelists = sys.argv[4:]
  s3 = boto3.client('s3')
  put_files = [f for l in [ open(f, 'r').read().rstrip('\n').split('\n') for f in changelists ] for f in l]
  c = len(put_files)
  i = 1
  for f in put_files :
    print(f'{i}/{c}')
    i += 1
    if not os.path.exists(f) :
      continue
    relative_path = path_prefix.lstrip('/') + f.replace(prefix, '', 1).lstrip('/')
    print(f'Copying {f} to s3://{bucket}/{relative_path}')
    f_obj = open(f, 'rb')
    s3.put_object(ACL='public-read', Body=f_obj, Bucket = bucket, Key=relative_path)
    f_obj.close()

if __name__ == '__main__' :
  main()
