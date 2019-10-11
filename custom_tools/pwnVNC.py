#!/usr/bin/env python
import socket
import os
import sys

CURRENT_INDEX = 0

#############################################################################################################
# Connect to designated IP over given port. Negotiate RFB version handshake + capture authentication methods #
# Returns '1' if no authentication is needed, else returns '0'                                              #
#############################################################################################################
def get_security(TCP_IP, TCP_PORT):
    snapshot_flag = 0
    vnc_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    vnc_socket.settimeout(0.5)
    try:
        vnc_socket.connect(( TCP_IP,TCP_PORT ))
        RFB_VERSION = vnc_socket.recv(12)
        if "RFB" not in RFB_VERSION:
            return snapshot_flag
        vnc_socket.send(RFB_VERSION)
        num_of_auth = vnc_socket.recv(1)
        if not num_of_auth:
            return snapshot_flag
        for i in xrange(0,ord(num_of_auth)):
            if ord(vnc_socket.recv(1)) == 1:
                snapshot_flag = 1
            else:
                pass
        vnc_socket.shutdown(socket.SHUT_WR)
        vnc_socket.close()
    except socket.error:
        vnc_socket.close()
        pass
    except socket.timeout:
        vnc_socket.close()
        pass
    return snapshot_flag

################################################################################################
# Open list of IPs, call get_security() on each IP and snapshot if no authentication is needed #
################################################################################################
# alynch edits:
# accept as arguments:
# - ip to test
# - port to test
# 
if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: pwnVNC [ip] [port]")
        sys.exit()
    print "This program requires the user to have vncsnapshot downloaded and in the user's path. It can be cloned here: https://github.com/shamun/vncsnapshot\n"
    print "\nRunning ..."
    print "Note ... current index will be kept in new file 'index.txt' if for some reason the program is interrupted"
    ip_addr = sys.argv[1]
    port = sys.argv[2]
    vncsnap_flag = get_security(ip_addr, int(port))
    if vncsnap_flag == 1:
        print "IT'S INSECURE, SCREENSHOTTING"
        os.system("echo '" + ip_addr + " " + port + "' > pwnvnc-"+ip_addr+"-"+port+".txt")
        CMD = "timeout 10 vncsnapshot -allowblank " + ip_addr + "::" + port + " ../../public/ss/vnc-" + ip_addr + "-"+ port +".jpg > /dev/null 2>&1"
        print "CMD: " + CMD
        os.system(CMD)
    else:
        pass
