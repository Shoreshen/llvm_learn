#include "llvm/IR/Dominators.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/FileSystem.h"

#include "visit.h"
#include "output.h"

using namespace llvm;

cl::opt<std::string> input_filename(cl::Positional, cl::Required, cl::desc("<input file>"));
static cl::opt<std::string> ll_filename("ll", cl::desc("Specify ll filename"), cl::value_desc("filename"));

void check_cml_input() 
{
    if (!ll_filename.size() ) {
        size_t lastdot = input_filename.rfind('.');
        if (lastdot != std::string::npos) {
            ll_filename = input_filename.substr(0, lastdot) + ".ll";
        } else {
            ll_filename = input_filename + ".ll";
        }
    }
}

int main(int argc, char **argv)
{
    cl::ParseCommandLineOptions(argc, argv); 
    check_cml_input();

    // parse bc file, get module
    LLVMContext CurrContext;
    SMDiagnostic Err;
    std::unique_ptr<Module> mod = parseIRFile(input_filename, Err, CurrContext);
    if (!mod) {
        Err.print(argv[0], errs());
        return 1;
    }
    
    // visit module
    // mod->print(errs(), nullptr);
    visit(mod.get());

    // write to file
    write_file(mod.get(), "param_map.txt", ll_filename);

    return 0;
}
