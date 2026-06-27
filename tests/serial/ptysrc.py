import os, time, sys
master, slave = os.openpty()
slave_path = os.ttyname(slave)
link = "/tmp/e68serial"
try: os.unlink(link)
except OSError: pass
os.symlink(slave_path, link)
sys.stderr.write("slave=%s link=%s\n" % (slave_path, link)); sys.stderr.flush()
# keep slave fd open (prevents hangup); never read it so the 68K reader gets data
import termios, tty
try: tty.setraw(master)
except Exception: pass
while True:
    try: os.write(master, b"PING ")
    except OSError: break
    time.sleep(0.05)
