//                        Caide C++ inliner
//
// This file is distributed under the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version. See LICENSE.TXT for details.

#pragma once

#include <vector>
#include <set>
#include <string>
#include <unordered_set>

namespace caide {
namespace internal {

// Second inliner stage: remove unused code
class Optimizer {
public:
    Optimizer(const std::vector<std::string>& cmdLineOptions,
              const std::vector<std::string>& macrosToKeep,
              const std::vector<std::string>& identifiersToKeep);

    // The file is read in binary mode, so the returned string is also
    // 'in binary mode' (contains \r\n on Windows)
    std::string doOptimize(const std::string& cppFile);

private:
    std::vector<std::string> cmdLineOptions;
    std::set<std::string> macrosToKeep;
    std::unordered_set<std::string> identifiersToKeep;
};

}
}

