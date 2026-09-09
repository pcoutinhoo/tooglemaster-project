import subprocess


def execute_command(command):
    subprocess.Popen(command, shell=True)
