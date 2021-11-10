import re
import json
import errno
import subprocess
import HtmlTestRunner
import unittest
import pexpect
import sys
import time
import os
import os.path
import getpass
from datetime import datetime
from pytz import timezone
import errno

g_relver=""
g_cluster=""
g_xy=""
g_ext=""

class SensSmoke(unittest.TestCase):

    def runcmd(self, cmd):
        ps = subprocess.call(['bash', '-c', cmd])
        if ps == 0:
            print("pass")
        else:
            print("Fail")
            sys.exit(-1)

    def run_helloapp(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' helloapp all-g ' + g_ext
        self.runcmd(cmd)

    def run_presidio(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' presidio all-g ' + g_ext
        self.runcmd(cmd)

    def run_ftxapp(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' ftxapp all-g ' + g_ext
        self.runcmd(cmd)

    def run_nlpapp(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' nlpapp all-g ' + g_ext
        self.runcmd(cmd)

    def run_pytorch(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' pytorch all-g ' + g_ext
        self.runcmd(cmd)

    def run_kafkatest(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' kafkatest all-g ' + g_ext
        self.runcmd(cmd)

    def run_dbapp(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' dbapp all-g ' + g_ext
        self.runcmd(cmd)

if __name__ == "__main__":
    #print(f"Arguments count: {len(sys.argv)}")
    if len(sys.argv) < 3:
        print("Usage: python3 test_drive.py <confprefix> <clustername> [external]")
        sys.exit(1)
    else:
        g_prefix=sys.argv[1]
        g_cluster=sys.argv[2]
        if len (sys.argv) > 3:
            g_ext=sys.argv[3]
        if g_cluster.startswith("aks-"):
           g_xy="aa"
           #xx=arg[len("aks-"):]
           #print(f"Argument {i:>6}: AZURE {arg} {xx}")
        elif g_cluster.startswith("gke-"):
           g_xy="gg"
           #xx=arg[len("gke-"):]
           #print(f"Argument {i:>6}: GOOGLE {arg} {xx}")
        else:
           print(f"UNKNOWN {g_cluster}")

    test_suit = unittest.TestSuite()
    test_suit.addTest(SensSmoke("run_helloapp"))
    test_suit.addTest(SensSmoke("run_presidio"))
    test_suit.addTest(SensSmoke("run_ftxapp"))
    test_suit.addTest(SensSmoke("run_nlpapp"))
    test_suit.addTest(SensSmoke("run_pytorch"))
    test_suit.addTest(SensSmoke("run_kafkatest"))
    test_suit.addTest(SensSmoke("run_dbapp"))
    smoke_tests = unittest.TestSuite(test_suit)
    outdir = os.environ['HOME'] + '/safectl_workspace/test_reports'
    repname=g_prefix + '-' + g_cluster
    tz = timezone('EST')
    now=datetime.now(tz)
    datestr=now.strftime("%Y%m%d-%H:%M:%S")
    logfile=outdir+'/'+datestr+'-'+repname+'.log'
    if not os.path.exists(os.path.dirname(logfile)):
        try:
            os.makedirs(os.path.dirname(logfile))
        except OSError as exc: # Guard against race condition
            if exc.errno != errno.EEXIST:
                raise
    print(f"{logfile}")
    sys.stdout=open(logfile, "w")
    unittest.TextTestRunner( sys.stdout, \
          verbosity=2).run(test_suit)
    #h = HtmlTestRunner.HTMLTestRunner(combine_reports=True, \
    #        output=outdir, report_name=repname).run(test_suit)
