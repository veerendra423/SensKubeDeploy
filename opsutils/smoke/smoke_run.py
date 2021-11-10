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
import getopt
import timeout_decorator

g_relver=""
g_cluster=""
g_xy=""
g_createcluster=False
g_ccmd=""
g_dcmd=""
g_fullsuite=False
g_extflag=False
g_ext=""
g_prefix=""
g_singlenode=""
g_timeout=1200

class SensSmoke(unittest.TestCase):

    i_flag=False
    def setUp(self):
        if self.__class__.i_flag:
            self.skipTest("skipping")
        pass

    def runcmd(self, cmd, ret=0):
        ps = subprocess.call(['bash', '-c', cmd])
        if ps == 0:
            if ret == 1:
                return 0
            print("pass")
        else:
            if ret == 1:
                return -1
            else:
                print("Fail")
                sys.exit(-1)

    def a_create_cluster(self):
        if not g_createcluster:
           print("pass")
        else:
           cmd = 'pushd ../../ && ' + g_ccmd + ' && popd'
           r=self.runcmd(cmd, 1)
           if r != 0:
              self.__class__.i_flag=True
              sys.exit(-1)
           else:
              print("pass")


    def b_setup_safectl(self):
        cmd = "./setup_safectl.sh release " + g_relver
        self.runcmd(cmd)

    def c_switch_to_cluster(self):
        cmd = 'yes | ../switchtocluster.sh ' + g_cluster 
        self.runcmd(cmd)

    def d0_run_install_aaa(self):
        cmd = 'cp /mnt/staging/reference-configs/aaa-' + g_xy + \
                '-overrides.custom.env ../../config/overrides.custom.env && \
                pushd ../../ && ./sensdelete.sh && \
                ./getsensenv.sh ' + g_relver + ' && ./sensinstall.sh && popd'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d1_run_aaa_helloapp(self):
        cmd = './run_safectl.sh aaa ' + g_cluster + ' helloapp all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d2_run_aaa_presidio(self):
        cmd = './run_safectl.sh aaa ' + g_cluster + ' presidio all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d3_run_aaa_ftxapp(self):
        cmd = './run_safectl.sh aaa ' + g_cluster + ' ftxapp all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d4_run_aaa_nlpapp(self):
        cmd = './run_safectl.sh aaa ' + g_cluster + ' nlpapp all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d5_run_aaa_pytorch(self):
        cmd = './run_safectl.sh aaa ' + g_cluster + ' pytorch all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d6_run_aaa_kafkatest(self):
        cmd = './run_safectl.sh aaa ' + g_cluster + ' kafkatest all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d7_run_aaa_dbapp(self):
        cmd = './run_safectl.sh aaa ' + g_cluster + ' dbapp all-g'
        self.runcmd(cmd)

    def e0_run_install_aww(self):
        cmd = 'cp /mnt/staging/reference-configs/aww-' + g_xy + \
                '-overrides.custom.env ../../config/overrides.custom.env && \
                pushd ../../ && ./sensdelete.sh && \
                ./getsensenv.sh ' + g_relver + ' && ./sensinstall.sh && popd'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def e1_run_aww_helloapp(self):
        cmd = './run_safectl.sh aww ' + g_cluster + ' helloapp all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def e2_run_aww_presidio(self):
        cmd = './run_safectl.sh aww ' + g_cluster + ' presidio all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def e3_run_aww_ftxapp(self):
        cmd = './run_safectl.sh aww ' + g_cluster + ' ftxapp all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def e4_run_aww_nlpapp(self):
        cmd = './run_safectl.sh aww ' + g_cluster + ' nlpapp all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def e5_run_aww_pytorch(self):
        cmd = './run_safectl.sh aww ' + g_cluster + ' pytorch all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def e6_run_aww_kafkatest(self):
        cmd = './run_safectl.sh aww ' + g_cluster + ' kafkatest all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def e7_run_aww_dbapp(self):
        cmd = './run_safectl.sh aww ' + g_cluster + ' dbapp all-g'
        self.runcmd(cmd)

    def f0_run_install_ggg(self):
        cmd = 'cp /mnt/staging/reference-configs/ggg-' + g_xy + \
                '-overrides.custom.env ../../config/overrides.custom.env && \
                pushd ../../ && ./sensdelete.sh && \
                ./getsensenv.sh ' + g_relver + ' && ./sensinstall.sh && popd'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def f1_run_ggg_helloapp(self):
        cmd = './run_safectl.sh ggg ' + g_cluster + ' helloapp all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def f2_run_ggg_presidio(self):
        cmd = './run_safectl.sh ggg ' + g_cluster + ' presidio all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def f3_run_ggg_ftxapp(self):
        cmd = './run_safectl.sh ggg ' + g_cluster + ' ftxapp all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def f4_run_ggg_nlpapp(self):
        cmd = './run_safectl.sh ggg ' + g_cluster + ' nlpapp all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def f5_run_ggg_pytorch(self):
        cmd = './run_safectl.sh ggg ' + g_cluster + ' pytorch all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def f6_run_ggg_kafkatest(self):
        cmd = './run_safectl.sh ggg ' + g_cluster + ' kafkatest all-g'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def f7_run_ggg_dbapp(self):
        cmd = './run_safectl.sh ggg ' + g_cluster + ' dbapp all-g'
        self.runcmd(cmd)

    def g_cleanup(self):
        cmd = 'pushd ../../ && rm -f config/overrides.custom.env && \
                ./sensdelete.sh && popd'

    def h_delete_cluster(self):
        if not g_createcluster:
           print("pass")
        else:
           cmd = 'pushd ../../ && ' + g_dcmd + ' && popd'
           r=self.runcmd(cmd)

    def d0_run_install_prefix(self):
        cmd = 'cp /mnt/staging/reference-configs/' + g_prefix + '-' + g_xy + \
                '-overrides.custom.env ../../config/overrides.custom.env && \
                pushd ../../ && ./sensdelete.sh && \
                ./getsensenv.sh ' + g_relver + ' && ./sensinstall.sh && popd'
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d1_run_helloapp(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' helloapp all-g ' + g_ext
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d2_run_presidio(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' presidio all-g ' + g_ext
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d3_run_ftxapp(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' ftxapp all-g ' + g_ext
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d4_run_nlpapp(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' nlpapp all-g ' + g_ext
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d5_run_pytorch(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' pytorch all-g ' + g_ext
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d6_run_kafkatest(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' kafkatest all-g ' + g_ext
        self.runcmd(cmd)

    @timeout_decorator.timeout(g_timeout)
    def d7_run_dbapp(self):
        cmd = './run_safectl.sh ' + g_prefix + ' ' + g_cluster + ' dbapp all-g ' + g_ext
        self.runcmd(cmd)

if __name__ == "__main__":

    opts, args = getopt.getopt(sys.argv[1:], 'hecfsr:k:p:')

    for (o, v) in opts:
        if o == '-h':
            print("""usage: %s -h |
                    [ [-c] [-s] [-f] | [-e] -p <safectlenvprefix> ] -r <release> -k <kubernetes cluster> 
            -h: help, -e: external (default is devel), -c: create a new cluster (default is no),
            -f: run the full test suite, -s: singlenode cluster
            Example: -r VERSION_1_4_0-RC1 -k aks-test"""%sys.argv[0])
            sys.exit(0)
        elif o == '-c':
            g_createcluster=True
            print("New cluster will be created")
        elif o == '-e':
            g_extflag=True
            g_ext="external"
            print("Subdomain: external")
        elif o == '-f':
            g_fullsuite=True
            print("Full test suite")
        elif o == '-s':
            g_singlenode="singlenode"
            print("Single node cluster")
        elif o == '-r':
            g_relver=v
        elif o == '-k':
            g_cluster=v
        elif o == '-p':
            g_prefix=v
        else:
            print(f"Uknown option: {o}")
            sys.exit(1)

    if g_extflag and g_createcluster:
       print("Cannot create external cluster")
       sys.exit(1)

    if g_extflag and g_fullsuite:
       print("Cannot run full suite of tests on external cluster")
       sys.exit(1)

    if g_extflag and (g_prefix == ""):
       print("Safectl env prefix required for external cluster")
       sys.exit(1)

    if g_relver == "":
        print("release version is required")
        sys.exit(1)

    elif g_cluster == "":
        print("cluster name is required")
        sys.exit(1)
    else:
        pass

    if g_cluster.startswith("aks-"):
       g_xy="aa"
       if g_prefix == "":
           g_prefix="axx"
       xx=g_cluster[len("aks-"):]
       g_ccmd = ' yes | ./akscreatecluster.sh ' + xx + ' RsrcGrpKubeIndia ' + g_singlenode + ' '
       g_dcmd = ' yes | ./aksdeletecluster.sh ' + xx + ' RsrcGrpKubeIndia '
       #print(f"Argument {i:>6}: AZURE {arg} {xx}")
    elif g_cluster.startswith("gke-g"):
       g_xy="gg"
       if g_prefix == "":
           g_prefix="gxx"
       xx=g_cluster[len("gke-g"):]
       g_ccmd = ' yes | ./gkecreatecluster.sh ' + xx + ' 52.255.140.176 ' + g_singlenode + ' '
       g_dcmd = ' yes | ./gkedeletecluster.sh ' + xx + ' '
       #print(f"Argument {i:>6}: GOOGLE {arg} {xx}")
    else:
       print(f"UNKNOWN cluster: {g_cluster}")
       sys.exit(1)

    test_suit = unittest.TestSuite()
    if not g_fullsuite:
       test_suit.addTest(SensSmoke("a_create_cluster"))
       test_suit.addTest(SensSmoke("b_setup_safectl"))
       if not g_extflag:
          test_suit.addTest(SensSmoke("c_switch_to_cluster"))
          test_suit.addTest(SensSmoke("d0_run_install_prefix"))
       test_suit.addTest(SensSmoke("d1_run_helloapp"))
       test_suit.addTest(SensSmoke("d2_run_presidio"))
       test_suit.addTest(SensSmoke("d3_run_ftxapp"))
       test_suit.addTest(SensSmoke("d4_run_nlpapp"))
       test_suit.addTest(SensSmoke("d5_run_pytorch"))
       test_suit.addTest(SensSmoke("d6_run_kafkatest"))
       test_suit.addTest(SensSmoke("d7_run_dbapp"))
       test_suit.addTest(SensSmoke("h_delete_cluster"))
    else:
       test_suit.addTest(SensSmoke("a_create_cluster"))
       test_suit.addTest(SensSmoke("b_setup_safectl"))
       test_suit.addTest(SensSmoke("c_switch_to_cluster"))
       test_suit.addTest(SensSmoke("d0_run_install_aaa"))
       test_suit.addTest(SensSmoke("d1_run_aaa_helloapp"))
       test_suit.addTest(SensSmoke("d2_run_aaa_presidio"))
       test_suit.addTest(SensSmoke("d3_run_aaa_ftxapp"))
       test_suit.addTest(SensSmoke("d4_run_aaa_nlpapp"))
       test_suit.addTest(SensSmoke("d5_run_aaa_pytorch"))
       test_suit.addTest(SensSmoke("d6_run_aaa_kafkatest"))
       test_suit.addTest(SensSmoke("d7_run_aaa_dbapp"))
       test_suit.addTest(SensSmoke("e0_run_install_aww"))
       test_suit.addTest(SensSmoke("e1_run_aww_helloapp"))
       test_suit.addTest(SensSmoke("e2_run_aww_presidio"))
       test_suit.addTest(SensSmoke("e3_run_aww_ftxapp"))
       test_suit.addTest(SensSmoke("e4_run_aww_nlpapp"))
       test_suit.addTest(SensSmoke("e5_run_aww_pytorch"))
       test_suit.addTest(SensSmoke("e6_run_aww_kafkatest"))
       test_suit.addTest(SensSmoke("e7_run_aww_dbapp"))
       test_suit.addTest(SensSmoke("f0_run_install_ggg"))
       test_suit.addTest(SensSmoke("f1_run_ggg_helloapp"))
       test_suit.addTest(SensSmoke("f2_run_ggg_presidio"))
       test_suit.addTest(SensSmoke("f3_run_ggg_ftxapp"))
       test_suit.addTest(SensSmoke("f4_run_ggg_nlpapp"))
       test_suit.addTest(SensSmoke("f5_run_ggg_pytorch"))
       test_suit.addTest(SensSmoke("f6_run_ggg_kafkatest"))
       test_suit.addTest(SensSmoke("f7_run_ggg_dbapp"))
       test_suit.addTest(SensSmoke("g_cleanup"))
       test_suit.addTest(SensSmoke("h_delete_cluster"))
    smoke_tests = unittest.TestSuite(test_suit)
    outdir = os.environ['HOME'] + '/safectl_workspace/test_reports'
    repname=g_relver + '-' + g_cluster
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
