import subprocess as sp

class RscriptRunner:
    def __init__(self, binary):
        self.binary = binary

    def __call__(self, script_path, arguments = [], cwd = None, output = False):
        command_line = [self.binary, script_path] + arguments

        print("Executing Rscript:")
        print("  " + " ".join(command_line))

        if output:
            return sp.check_output(command_line, cwd = cwd)
        else:
            return sp.check_call(command_line, cwd = cwd)

def configure(context, require):
    require.config("rscript_binary", "Rscript")
    # install package manager for R
    #sp.check_call([context.config["rscript_binary"], "-e", 'if (!require("pacman")) install.packages("pacman")'])
    #assert("3.5" in sp.check_output(["Rscript", "--version"], stderr = sp.STDOUT).decode("utf-8"))

def execute(context):
    return RscriptRunner(context.config["rscript_binary"])
