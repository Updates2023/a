from cmd import Cmd
import os
import collections
import binascii
import argparse
import sys
import platform

class Terminal(Cmd):
    intro = "Welcome to the turtle shell"
    prompt= "shell>"

    def converttohex(self,command):
        hex = bytes(command,'utf-8')
        hex=binascii.hexlify(hex)
        y=str(hex,'ascii')
        return y

    def do_run(self,arg):
        #if len(arg[1]) < 5:
        if(len(arg)>5):
            spli = arg.split()
            if spli:
                hex = self.converttohex(spli[0])
                hex2 = self.converttohex(spli[1])
                print (hex)
                print (hex2)
        else:
            pass
      #  if arg:
       #     print (f"command {bytes.fromhex(arg).decode('utf-8')} has already sent")
       # else:
          #  print ("command sent")
        #    print (arg)
         #   os.system(f"mkdir {arg}")
         #   arg.split(" ")
          #  print (arg[0])
       #print("[-] convert to hex")
       # hex=self.converttohex(arg)
       # print (hex)
    def help_run(self):
        print('writed command to the target directory "run <command>" ')

    def do_ls(self,command):
        "[-] list exists users"
        path= "C:\\users\\public"
        os.system(f"ls {path}")
    def help_ls(self):
        print("Get target Directory Listing")

    def do_cd(self,id):
        if platform.system() == "Windows":
            path = "C:\\users\\public\\"
        if platform.system()=="Linux":
            path = "/tmp/"
        result = os.chdir(f"{path}{id}")
        print(os.getcwd())
        print (f"changing directory to {id}")

    def do_shell(self,command):
        print ("running local command")
        os.system(command)
    def help_shell(slef):
        print('Execute a shell command "shell <command>"')

    def do_clear(self,command):
        os.system("clear")


cm = Terminal()

try:
    cm.cmdloop()
except KeyboardInterrupt:
   print ("Shutdown requested...exiting")

