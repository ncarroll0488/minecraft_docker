import mcrcon, time, sys, signal, getpass, readline

def shutdown(sig, frame) :
  global r
  r.disconnect()
  r = None
  print('')
  exit(0)

def main() :
  global r
  try :
    addr = sys.argv[1]
    port = int(sys.argv[2])
  except :
    print('Missing args')
    return(1)
  r = mcrcon.MCRcon()
  try :
    passfile = sys.argv[3]
    fd = open(passfile, 'r')
    password = fd.read().rstrip('\n')
    fd.close()
  except Exception as e:
    print(e)
    try :
      password = getpass.getpass('Password (ctrl+D for none): ')
    except EOFError :
      password = ''
  r.connect(addr,port,password)
  prompt = '{}:{}> '.format(addr,port)
  while True :
    try :
      cmd = input(prompt)
      print(r.command(cmd))
    except EOFError :
      print('')
      return(0)
    except Exception as e :
      print(e)

if __name__ == '__main__' :
  signal.signal(signal.SIGHUP, shutdown)
  signal.signal(signal.SIGINT, shutdown)
  signal.signal(signal.SIGTERM, shutdown)
  exit(main())
